/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IVault.sol";
import "../interfaces/IMainRegistry.sol";
import "../interfaces/IIntegrationManager.sol";
import "../../lib/solmate/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";
import {AddressArrayLib} from "./utils/AddressArrayLib.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./utils/IIntegrationAdapter.sol";
import "./utils/VaultActionMixin.sol";

/// @title IntegrationManager
contract IntegrationManager is 
    Ownable,
    IIntegrationManager,
    VaultActionMixin
    {
    using FixedPointMathLib for uint256;
    using AddressArrayLib for address[];

    event CallOnIntegrationExecutedForVault(
        address caller, // vaultOwner or vaultDelegate 
        address indexed adapter, // adapter to use
        bytes4 indexed selector, // function of adapter to use
        bytes integrationData, // 
        address[] incomingAssets,
        uint256[] incomingAssetAmounts,
        address[] spendAssets,
        uint256[] spendAssetAmounts
    );

    address private immutable MAIN_REGISTRY;

    constructor(address _mainRegistry) public {
        MAIN_REGISTRY = _mainRegistry;
    }


    ///////////////////////////////
    // CALL-ON-EXTENSION ACTIONS //
    ///////////////////////////////

    /// @notice Receives a dispatched `callOnExtension` from a vault
    /// @param _caller The user who called for this action
    /// @param _callArgs The encoded args for the action
    function receiveCallFromVault(
        address _caller,
        bytes calldata _callArgs
    ) external {
        address vaultProxy = msg.sender;
        //Check on facotry is its is effectively a vault!!!!
        require(
            IVault(vaultProxy).owner() == _caller, //
            "receiveCallFromVaultProxy: Unauthorized"
        );
        __callOnIntegration(_caller, vaultProxy, _callArgs);
    }

    /////////////////////////
    // CALL ON INTEGRATION //
    /////////////////////////

    /// @notice Universal method for calling third party contract functions through adapters
    /// @param _caller The caller of this function via the ComptrollerProxy
    /// @param _vaultProxy The VaultProxy
    /// @param _callArgs The encoded args for this function
    /// - _adapter Adapter of the integration on which to execute a call
    /// - _selector Method selector of the adapter method to execute
    /// - _integrationData Encoded arguments specific to the adapter
    /// @dev Refer to specific adapter to see how to encode its arguments.
    function __callOnIntegration(
        address _caller,
        address _vaultProxy,
        bytes memory _callArgs
    ) private {
        (
            address adapter,
            bytes4 selector,
            bytes memory integrationData
        ) = __decodeCallOnIntegrationArgs(_callArgs);

        (
            actionAssetsData memory incomingAssets,
            actionAssetsData memory spendAssets
        ) = __callOnIntegrationInner(
                _vaultProxy,
                adapter,
                selector,
                integrationData
            );

        emit CallOnIntegrationExecutedForVault(
            _caller,
            adapter,
            selector,
            integrationData,
            incomingAssets.assets,
            incomingAssets.minmaxAssetAmounts,
            spendAssets.assets,
            spendAssets.minmaxAssetAmounts
        );
    }

    /// @dev Helper to execute the bulk of logic of callOnIntegration.
    /// Avoids the stack-too-deep-error.
    function __callOnIntegrationInner(
        address _vaultProxy,
        address _adapter,
        bytes4 _selector,
        bytes memory _integrationData
    )
        private
        returns (
            actionAssetsData memory incomingAssets_,
            actionAssetsData memory spendAssets_
        )
    {

        (
            incomingAssets_,
            spendAssets_
        ) = __preProcessCoI(_vaultProxy, _adapter, _selector, _integrationData);

        __executeCoI(
            _vaultProxy,
            _adapter,
            _selector,
            _integrationData,
            abi.encode(spendAssets_.assets, spendAssets_.minmaxAssetAmounts, incomingAssets_.assets)
        );

        (incomingAssets_, spendAssets_) = __postProcessCoI(
            _vaultProxy,
            _adapter,
            incomingAssets_,
            spendAssets_
        );

        return (incomingAssets_, spendAssets_);
    }


    /// @dev Helper to execute a call to an integration
    /// @dev Avoids stack-too-deep error
    function __executeCoI(
        address _vaultProxy,
        address _adapter,
        bytes4 _selector,
        bytes memory _integrationData,
        bytes memory _assetData
    ) private {
        (bool success, bytes memory returnData) = _adapter.call(
            abi.encodeWithSelector(_selector, _vaultProxy, _integrationData, _assetData)
        );
        require(success, string(returnData));
    }

    /// @dev Helper to get the vault's balance of a particular asset
    function __getVaultAssetBalance(address _vaultProxy, address _asset)
        private
        view
        returns (uint256)
    {
        return ERC20(_asset).balanceOf(_vaultProxy);
    }

       /// @dev Helper to decode CoI args
    function __decodeCallOnIntegrationArgs(bytes memory _callArgs)
        private
        pure
        returns (
            address adapter_,
            bytes4 selector_,
            bytes memory integrationData_
        )
    {
        return abi.decode(_callArgs, (address, bytes4, bytes));
    }

    /// @dev Helper for the internal actions to take prior to executing CoI
    
    function __preProcessCoI(
        address _vaultProxy,
        address _adapter,
        bytes4 _selector,
        bytes memory _integrationData
    )
        private
        returns (
            actionAssetsData memory incomingAssets_,
            actionAssetsData memory spendAssets_
        )
    {

        // Note that incoming and spend assets are allowed to overlap
        // (e.g., a fee for the incomingAsset charged in a spend asset)
        (
            incomingAssets_, //switch?
            spendAssets_
        ) = IIntegrationAdapter(_adapter).parseAssetsForAction(
            _vaultProxy,
            _selector,
            _integrationData
        );

        require(
            spendAssets_.assets.length == spendAssets_.minmaxAssetAmounts.length,
            "__preProcessCoI: Spend assets arrays unequal"
        );
        require(
            incomingAssets_.assets.length == incomingAssets_.minmaxAssetAmounts.length,
            "__preProcessCoI: Incoming assets arrays unequal"
        );
        require(
            spendAssets_.assets.length == spendAssets_.assetIds.length,
            "__preProcessCoI: Spend assets arrays unequal"
        );
        require(
            incomingAssets_.assets.length == incomingAssets_.assetIds.length,
            "__preProcessCoI: Incoming assets arrays unequal"
        );
        require(spendAssets_.assets.isUniqueSet(), "__preProcessCoI: Duplicate spend asset");
        require(incomingAssets_.assets.isUniqueSet(), "__preProcessCoI: Duplicate incoming asset");
        require(spendAssets_.assetIds.isUniqueSet(), "__preProcessCoI: Duplicate spend assetId");
        require(incomingAssets_.assetIds.isUniqueSet(), "__preProcessCoI: Duplicate incoming assetId");

        // INCOMING ASSETS

        // Incoming asset balances must be recorded prior to spend asset balances in case there
        // is an overlap (an asset that is both a spend asset and an incoming asset),
        // as a spend asset can be immediately transferred after recording its balance
        
        incomingAssets_.preCallAssetBalances = new uint256[](incomingAssets_.assets.length);
        require(
                IMainRegistry(getMainRegistry()).batchIsWhiteListed(incomingAssets_.assets, incomingAssets_.assetIds),
                "__preProcessCoI: Non-whitelisted incoming asset"
        );
        
        for (uint256 i; i < incomingAssets_.assets.length; i++) {
            incomingAssets_.preCallAssetBalances[i] = ERC20(incomingAssets_.assets[i]).balanceOf(_vaultProxy);
        }

        // SPEND ASSETS

        spendAssets_.preCallAssetBalances = new uint256[](spendAssets_.assets.length);
        for (uint256 i; i < spendAssets_.assets.length; i++) {
            spendAssets_.preCallAssetBalances[i] = ERC20(spendAssets_.assets[i]).balanceOf(_vaultProxy);

            // Grant adapter access to the spend assets.
            // spendAssets_ is already asserted to be a unique set.       
            // Use exact approve amount, and reset afterwards
            __approveAssetSpender(
                _vaultProxy,
                spendAssets_.assets[i],
                _adapter,
                spendAssets_.minmaxAssetAmounts[i]
                );
         
            }
        }

    /// @dev Helper to reconcile incoming and spend assets after executing CoI
    function __postProcessCoI(
        address _vaultProxy,
        address _adapter,
        actionAssetsData memory spendAssets_,
        actionAssetsData memory incomingAssets_
    )
        private
        returns (uint256[] memory incomingAssetAmounts_, uint256[] memory spendAssetAmounts_)
        {

        //INCOMING ASSETS

        incomingAssetsAmounts_ = new uint256[](incomingAssets_.assets.length);
        for (uint256 i; i < incomingAssets_.assets.length; i++) {
            incomingAssetsAmounts_[i] = __getVaultAssetBalance(_vaultProxy, incomingAssets_.assets[i]).sub(
                incomingAssets_.preCallAssetBalances[i]
            );
            require(
                incomingAssetAmounts_[i] >= incomingAssets_.minmaxAssetAmounts[i],
                "__postProcessCoI: Received incoming asset less than expected"
            );

        }

        // RESET cl thres after swap
        // SPEND ASSETS

        spendAssetAmounts_ = new uint256[](spendAssets_.assets.length);
        for (uint256 i; i < _spendAssets.length; i++) {
            // Calculate the balance change of spend assets. Ignore if balance increased.
            uint256 postCallAssetBalance = __getVaultAssetBalance(
                _vaultProxy,
                _spendAssets.assets[i]
            );
            if (postCallAssetBalance < spendAssets_.preCallAssetBalances[i]) {
                spendAssetAmounts_[i] = spendAssets_.preCallAssetBalances[i].sub(
                    postCallSpendAssetBalance
                );
            }


            //TODO Reset any unused approvals 
            // calculate real time --> should trigger update of col htres and liq thress
            if (
                ERC20(spendAssets_.assets[i]).allowance(_vaultProxy, _adapter) > 0
            ) {
                __approveAssetSpender(_vaultProxy, _spendAssets.assets[i], _adapter, 0);
            // } else if (_spendAssetsHandleType == SpendAssetsHandleType.None) {
            //     // Only need to validate _maxSpendAssetAmounts if not SpendAssetsHandleType.Approve
            //     // or SpendAssetsHandleType.Transfer, as each of those implicitly validate the max
            //     require(
            //         spendAssetAmounts_[i] <= spendAssets_.minmaxAssetAmounts[i],
            //         "__postProcessCoI: Spent amount greater than expected"
            //     );
            // }
            }
        }

        return (spendAssets__, incomingAssets__);
    }

    /////////////////
    //STATE GETTERS //
    /////////////////

    /// @notice Gets the `MAIN_REGISTRY` variable
    /// @return mainRegistry_ The `MAIN_REGISTRY` variable value
   function getMainRegistry() public view returns (address mainRegistry_) {
        return MAIN_REGISTRY;
    }
    }