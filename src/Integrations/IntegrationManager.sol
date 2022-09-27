/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IVault.sol";
import "../interfaces/IMainRegistry.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IIntegrationManager.sol";
import "../../lib/solmate/src/tokens/ERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol"; 



/// @title IntegrationManager
contract IntegrationManager is 
    Ownable,
    IIntegrationManager
    {

    address private immutable MAIN_REGISTRY;
    mapping(address => bool) public adapterWhitelist;

    struct actionAssetsData { 
                address[] assets;
                uint256[] assetIds;
                uint256[] preCallAssetBalances;
                uint256[] minmaxAssetAmounts;
                uint256[] assetAmounts;
        }
    

    constructor(address _mainRegistry) public {
        MAIN_REGISTRY = _mainRegistry;
    }

    /// @notice Receives a dispatched `action` from a vault
    /// @param _caller The user who called for this action
    /// @param _callArgs The encoded args for the action
    function receiveCallFromVault(
        address _caller,
        bytes calldata _callArgs
    ) external {
        _performCallToAdapter(msg.sender, _callArgs);
    }

    /// @notice Universal method for calling third party contract functions through adapters
    /// @param _vaultAddress The VaultAddress
    /// @param _callArgs The encoded args for this function
    /// - _adapter Adapter of the integration on which to execute a call
    /// - _selector Method selector of the adapter method to execute
    /// - _integrationData Encoded arguments specific to the adapter
    /// @dev Refer to specific adapter to see how to encode its arguments.
    function _performCallToAdapter(
        address _vaultAddress,
        bytes memory _callArgs
    ) private returns (actionAssetsData memory _outgoingAssets, actionAssetsData memory _incomingAssets) {
        (
            address adapter,
            bytes4 selector,
            bytes memory adapterData
        ) = abi.decode(_callArgs, (address, bytes4, bytes));

        (
            _outgoingAssets,
            _incomingAssets
        ) = _preProcessCall(_vaultAddress, adapter, selector, adapterData);

        _performCall(
            _vaultAddress,
            adapter,
            selector,
            adapterData,
            abi.encode(_outgoingAssets,_incomingAssets)
        );

        (
            _outgoingAssets.assetAmounts,
            _incomingAssets.assetAmounts
        ) = _postProcessCall(
            _vaultAddress,
            adapter,
            _outgoingAssets,
            _incomingAssets
        );
    }

    function _performCall(
        address _vaultAddress,
        address _adapter,
        bytes4 _selector,
        bytes memory _integrationData,
        bytes memory _assetData
    ) private {
        (bool success, bytes memory returnData) = _adapter.call(
            abi.encodeWithSelector(_selector, _vaultAddress, _integrationData, _assetData)
        );
        require(success, string(returnData));
    }

    /// @dev Helper to get the vault's balance of a particular asset
    function _getVaultAssetBalance(address _vaultAddress, address _asset)
        private
        view
        returns (uint256)
    {
        return ERC20(_asset).balanceOf(_vaultAddress);
    }

    /// @dev Helper for the internal actions to take prior to executing CoI
    
    function _preProcessCall(
        address _vaultAddress,
        address _adapter,
        bytes4 _selector,
        bytes memory _integrationData
    )
        private
        returns (
            actionAssetsData memory incomingAssets_,
            actionAssetsData memory outgoingAssets_
        )
    {

        // Note that incoming and outgoing assets are allowed to overlap
        // (e.g., a fee for the incomingAsset charged in a outgoing asset)
        (
            incomingAssets_, //switch?
            outgoingAssets_
        ) = IAdapter(_adapter).parseAssetsForAction(
            _vaultAddress,
            _selector,
            _integrationData
        );

        require(
            outgoingAssets_.assets.length == outgoingAssets_.minmaxAssetAmounts.length,
            "IM: Outgoing assets arrays unequal"
        );
        require(
            incomingAssets_.assets.length == incomingAssets_.minmaxAssetAmounts.length,
            "IM: Incoming assets arrays unequal"
        );
        require(
            outgoingAssets_.assets.length == outgoingAssets_.assetIds.length,
            "IM: Outgoing assets arrays unequal"
        );
        require(
            incomingAssets_.assets.length == incomingAssets_.assetIds.length,
            "IM: Incoming assets arrays unequal"
        );

        // INCOMING ASSETS

        // Incoming asset balances must be recorded prior to spend asset balances in case there
        // is an overlap (an asset that is both a spend asset and an incoming asset),
        // as a spend asset can be immediately transferred after recording its balance
        
        incomingAssets_.preCallAssetBalances = new uint256[](incomingAssets_.assets.length);
        require(
                IMainRegistry(MAIN_REGISTRY).batchIsWhiteListed(incomingAssets_.assets, incomingAssets_.assetIds),
                "IM: Non-whitelisted incoming asset"
        );
        
        for (uint256 i; i < incomingAssets_.assets.length; i++) {
            incomingAssets_.preCallAssetBalances[i] = ERC20(incomingAssets_.assets[i]).balanceOf(_vaultAddress);
        }

        // SPEND ASSETS

        outgoingAssets_.preCallAssetBalances = new uint256[](outgoingAssets_.assets.length);
        for (uint256 i; i < outgoingAssets_.assets.length; i++) {
            outgoingAssets_.preCallAssetBalances[i] = ERC20(outgoingAssets_.assets[i]).balanceOf(_vaultAddress);

            // Grant adapter access to the spend assets.
            // outgoingAssets_ is already asserted to be a unique set.       
            // Use exact approve amount, and reset afterwards
            }
        }

    /// @dev Helper to reconcile incoming and spend assets after executing CoI
    function _postProcessCall(
        address _vaultAddress,
        address _adapter,
        actionAssetsData memory outgoingAssets_,
        actionAssetsData memory incomingAssets_
    )
        private
        returns (uint256[] memory incomingAssetAmounts_, uint256[] memory outgoingAssetAmounts_)
        {
        //INCOMING ASSETS

        incomingAssetAmounts_ = new uint256[](incomingAssets_.assets.length);
        for (uint256 i; i < incomingAssets_.assets.length; i++) {
            incomingAssetAmounts_[i] = _getVaultAssetBalance(_vaultAddress, incomingAssets_.assets[i]) - incomingAssets_.preCallAssetBalances[i]; //check overflow
            require(
                incomingAssetAmounts_[i] >= incomingAssets_.minmaxAssetAmounts[i],
                "__postProcessCoI: Received incoming asset less than expected"
            );

        }
        // OUGOING ASSETS

        outgoingAssetAmounts_ = new uint256[](outgoingAssets_.assets.length);
        for (uint256 i; i < outgoingAssets_.assets.length; i++) {
            // Calculate the balance change of spend assets. Ignore if balance increased.
            uint256 postCallAssetBalance = _getVaultAssetBalance(
                _vaultAddress,
                outgoingAssets_.assets[i]
            );
            if (postCallAssetBalance < outgoingAssets_.preCallAssetBalances[i]) {
                outgoingAssetAmounts_[i] = outgoingAssets_.preCallAssetBalances[i] - 
                    postCallAssetBalance;
            }


        // CHECK LIQ AND STUFF HERE
        // RESET COL THRESH thres after swap
        // AFTER
            //TODO Reset any unused approvals 
            // calculate real time --> should trigger update of col htres and liq thress
            // if (
            //     ERC20(outgoingAssets_.assets[i]).allowance(_vaultAddress, _adapter) > 0
            // ) {
            //     __approveAssetSpender(_vaultAddress, outgoingAssets_.assets[i], _adapter, 0);
            //     require(
            //         outgoingAssetAmounts_[i] <= outgoingAssets_.minmaxAssetAmounts[i],
            //         "IM: Spent amount greater than expected"
            //     );
            // }
        }

        return (incomingAssetAmounts_, outgoingAssetAmounts_);
    }

    function addWhitelist(address newAdapterAddress) public onlyOwner {
        adapterWhitelist[newAdapterAddress] = true;
    }

    function removeWhitelist(address newAdapterAddress) public onlyOwner {
        adapterWhitelist[newAdapterAddress] = false;
    }

    }