/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IVault.sol";
import "../../lib/solmate/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title IntegrationManager
contract IntegrationManager is Ownable
    {
    using FixedPointMathLib for uint256;

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

    // figure out value interpreter
    constructor() public {}


    // /////////////
    // // GENERAL //
    // /////////////

    // /// @notice Enables the IntegrationManager to be used by a vault
    // /// @param _comptrollerProxy The ComptrollerProxy of the fund
    // /// @param _vaultProxy The VaultProxy of the fund
    // function setConfigForFund(
    //     address _comptrollerProxy,
    //     address _vaultProxy,
    //     bytes calldata
    // ) external override onlyFundDeployer {
    //     __setValidatedVaultProxy(_comptrollerProxy, _vaultProxy);
    // }

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
            address[] memory incomingAssets,
            uint256[] memory incomingAssetAmounts,
            address[] memory spendAssets,
            uint256[] memory spendAssetAmounts
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
            incomingAssets,
            incomingAssetAmounts,
            spendAssets,
            spendAssetAmounts
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
            address[] memory incomingAssets_,
            uint256[] memory incomingAssetAmounts_,
            address[] memory spendAssets_,
            uint256[] memory spendAssetAmounts_
        )
    {
        uint256[] memory preCallIncomingAssetBalances;
        uint256[] memory minIncomingAssetAmounts;
        // SpendAssetsHandleType spendAssetsHandleType;
        uint256[] memory maxSpendAssetAmounts;
        uint256[] memory preCallSpendAssetBalances;

        // (
        //     incomingAssets_,
        //     preCallIncomingAssetBalances,
        //     minIncomingAssetAmounts,
        //     spendAssetsHandleType,
        //     spendAssets_,
        //     maxSpendAssetAmounts,
        //     preCallSpendAssetBalances
        // ) = __preProcessCoI(_comptrollerProxy, _vaultProxy, _adapter, _selector, _integrationData);

        __executeCoI(
            _vaultProxy,
            _adapter,
            _selector,
            _integrationData,
            abi.encode(spendAssets_, maxSpendAssetAmounts, incomingAssets_)
        );

        // (incomingAssetAmounts_, spendAssetAmounts_) = __postProcessCoI(
        //     _comptrollerProxy,
        //     _vaultProxy,
        //     _adapter,
        //     incomingAssets_,
        //     preCallIncomingAssetBalances,
        //     minIncomingAssetAmounts,
        //     spendAssetsHandleType,
        //     spendAssets_,
        //     maxSpendAssetAmounts,
        //     preCallSpendAssetBalances
        // );

        return (incomingAssets_, incomingAssetAmounts_, spendAssets_, spendAssetAmounts_);
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

    // /// @dev Helper for the internal actions to take prior to executing CoI
    // function __preProcessCoI(
    //     address _comptrollerProxy,
    //     address _vaultProxy,
    //     address _adapter,
    //     bytes4 _selector,
    //     bytes memory _integrationData
    // )
    //     private
    //     returns (
    //         address[] memory incomingAssets_,
    //         uint256[] memory preCallIncomingAssetBalances_,
    //         uint256[] memory minIncomingAssetAmounts_,
    //         SpendAssetsHandleType spendAssetsHandleType_,
    //         address[] memory spendAssets_,
    //         uint256[] memory maxSpendAssetAmounts_,
    //         uint256[] memory preCallSpendAssetBalances_
    //     )
    // {
    //     // Note that incoming and spend assets are allowed to overlap
    //     // (e.g., a fee for the incomingAsset charged in a spend asset)
    //     (
    //         spendAssetsHandleType_,
    //         spendAssets_,
    //         maxSpendAssetAmounts_,
    //         incomingAssets_,
    //         minIncomingAssetAmounts_
    //     ) = IIntegrationAdapter(_adapter).parseAssetsForAction(
    //         _vaultProxy,
    //         _selector,
    //         _integrationData
    //     );
    //     require(
    //         spendAssets_.length == maxSpendAssetAmounts_.length,
    //         "__preProcessCoI: Spend assets arrays unequal"
    //     );
    //     require(
    //         incomingAssets_.length == minIncomingAssetAmounts_.length,
    //         "__preProcessCoI: Incoming assets arrays unequal"
    //     );
    //     require(spendAssets_.isUniqueSet(), "__preProcessCoI: Duplicate spend asset");
    //     require(incomingAssets_.isUniqueSet(), "__preProcessCoI: Duplicate incoming asset");

    //     // INCOMING ASSETS

    //     // Incoming asset balances must be recorded prior to spend asset balances in case there
    //     // is an overlap (an asset that is both a spend asset and an incoming asset),
    //     // as a spend asset can be immediately transferred after recording its balance
    //     preCallIncomingAssetBalances_ = new uint256[](incomingAssets_.length);
    //     for (uint256 i; i < incomingAssets_.length; i++) {
    //         require(
    //             IValueInterpreter(getValueInterpreter()).isSupportedAsset(incomingAssets_[i]),
    //             "__preProcessCoI: Non-receivable incoming asset"
    //         );

    //         preCallIncomingAssetBalances_[i] = ERC20(incomingAssets_[i]).balanceOf(_vaultProxy);
    //     }

    //     // SPEND ASSETS

    //     preCallSpendAssetBalances_ = new uint256[](spendAssets_.length);
    //     for (uint256 i; i < spendAssets_.length; i++) {
    //         preCallSpendAssetBalances_[i] = ERC20(spendAssets_[i]).balanceOf(_vaultProxy);

    //         // Grant adapter access to the spend assets.
    //         // spendAssets_ is already asserted to be a unique set.
    //         if (spendAssetsHandleType_ == SpendAssetsHandleType.Approve) {
    //             // Use exact approve amount, and reset afterwards
    //             __approveAssetSpender(
    //                 _comptrollerProxy,
    //                 spendAssets_[i],
    //                 _adapter,
    //                 maxSpendAssetAmounts_[i]
    //             );
    //         } else if (spendAssetsHandleType_ == SpendAssetsHandleType.Transfer) {
    //             __withdrawAssetTo(
    //                 _comptrollerProxy,
    //                 spendAssets_[i],
    //                 _adapter,
    //                 maxSpendAssetAmounts_[i]
    //             );
    //         }
    //     }
    // }

    // /// @dev Helper to reconcile incoming and spend assets after executing CoI
    // function __postProcessCoI(
    //     address _comptrollerProxy,
    //     address _vaultProxy,
    //     address _adapter,
    //     address[] memory _incomingAssets,
    //     uint256[] memory _preCallIncomingAssetBalances,
    //     uint256[] memory _minIncomingAssetAmounts,
    //     SpendAssetsHandleType _spendAssetsHandleType,
    //     address[] memory _spendAssets,
    //     uint256[] memory _maxSpendAssetAmounts,
    //     uint256[] memory _preCallSpendAssetBalances
    // )
    //     private
    //     returns (uint256[] memory incomingAssetAmounts_, uint256[] memory spendAssetAmounts_)
    // {
    //     // INCOMING ASSETS

    //     incomingAssetAmounts_ = new uint256[](_incomingAssets.length);
    //     for (uint256 i; i < _incomingAssets.length; i++) {
    //         incomingAssetAmounts_[i] = __getVaultAssetBalance(_vaultProxy, _incomingAssets[i]).sub(
    //             _preCallIncomingAssetBalances[i]
    //         );
    //         require(
    //             incomingAssetAmounts_[i] >= _minIncomingAssetAmounts[i],
    //             "__postProcessCoI: Received incoming asset less than expected"
    //         );

    //         // Even if the asset's previous balance was >0, it might not have been tracked
    //         __addTrackedAsset(_comptrollerProxy, _incomingAssets[i]);
    //     }

    //     // SPEND ASSETS

    //     spendAssetAmounts_ = new uint256[](_spendAssets.length);
    //     for (uint256 i; i < _spendAssets.length; i++) {
    //         // Calculate the balance change of spend assets. Ignore if balance increased.
    //         uint256 postCallSpendAssetBalance = __getVaultAssetBalance(
    //             _vaultProxy,
    //             _spendAssets[i]
    //         );
    //         if (postCallSpendAssetBalance < _preCallSpendAssetBalances[i]) {
    //             spendAssetAmounts_[i] = _preCallSpendAssetBalances[i].sub(
    //                 postCallSpendAssetBalance
    //             );
    //         }

    //         // Reset any unused approvals
    //         if (
    //             _spendAssetsHandleType == SpendAssetsHandleType.Approve &&
    //             ERC20(_spendAssets[i]).allowance(_vaultProxy, _adapter) > 0
    //         ) {
    //             __approveAssetSpender(_comptrollerProxy, _spendAssets[i], _adapter, 0);
    //         } else if (_spendAssetsHandleType == SpendAssetsHandleType.None) {
    //             // Only need to validate _maxSpendAssetAmounts if not SpendAssetsHandleType.Approve
    //             // or SpendAssetsHandleType.Transfer, as each of those implicitly validate the max
    //             require(
    //                 spendAssetAmounts_[i] <= _maxSpendAssetAmounts[i],
    //                 "__postProcessCoI: Spent amount greater than expected"
    //             );
    //         }
    //     }

    //     return (incomingAssetAmounts_, spendAssetAmounts_);
    // }

    ///////////////////
    // STATE GETTERS //
    ///////////////////

    // /// @notice Gets the `VALUE_INTERPRETER` variable
    // /// @return valueInterpreter_ The `VALUE_INTERPRETER` variable value
    // function getValueInterpreter() public view returns (address valueInterpreter_) {
    //     return VALUE_INTERPRETER;
    // }
}
