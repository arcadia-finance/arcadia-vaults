/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "./utils/AssetActionData.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IMainRegistry.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IIntegrationManager.sol";
import "../../lib/solmate/src/tokens/ERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

// Adapter Call Flow

// vaultOwner calls 'performAdapterCall' on vault with encoded callArgs.
// VAULT: delegates call to IM -> 'receiveCallFromVault'
// IM: 'receiveCallFromVault' calls _performCallAdapter
// #### msg.sender = vaultAddress
// #### _callArgs = encoded Args
// IM: '_performCallToAdapter' decodes _callArgs
// #### adapterAddress, adapterSelector,
// #### adapterData = encoded data the adapter need to perform the requested action.
// IM: '_preProcess' checks and calculates extra arguments needed to perform the requested action it returns actionAssetData for incoming and outgoing assets.
// #### Approve adapter to spend the outgoingAssets of the vault.
// IM: '_performCall' encode actionAssetData for incoming and outgoing assets and pass it along to delegatecall to 'adapterAddress'
// IM: '_postProcess' if the adapterAction went as expected and the balances are what expected

/// @title IntegrationManager
contract IntegrationManager is Ownable, IIntegrationManager {
    address public MAIN_REGISTRY;
    mapping(address => bool) public adapterWhitelist;

    constructor(address _mainRegistry) {
        MAIN_REGISTRY = _mainRegistry;
    }

    /// @notice Receives a dispatched `action` from a vault
    /// @param _callArgs The encoded args for the action
    function receiveCallFromVault(address caller, bytes calldata _callArgs) external {
        //calls the helper function add check back
        require(IVault(msg.sender).owner() == caller, "IM: Caller needs to own the vault");
        _performCallToAdapter(msg.sender, _callArgs);
    }

    /// @notice Universal method for calling third party contract functions through adapters
    /// @param _vaultAddress The VaultAddress
    /// @param _callArgs The encoded args for this function
    /// - _adapter Adapter of the integration on which to execute a call
    /// - _selector Method selector of the adapter method to execute
    /// - _integrationData Encoded arguments specific to the adapter
    /// @dev Refer to specific adapter to see how to encode its arguments.
    function _performCallToAdapter(address _vaultAddress, bytes memory _callArgs)
        private
        returns (actionAssetsData memory _outgoingAssets, actionAssetsData memory _incomingAssets)
    {
        (address adapter, bytes4 selector, bytes memory adapterData) = abi.decode(_callArgs, (address, bytes4, bytes));

        (_outgoingAssets, _incomingAssets) = _preProcessCall(_vaultAddress, adapter, selector, adapterData);

        _performCall(_vaultAddress, adapter, selector, adapterData, abi.encode(_outgoingAssets, _incomingAssets));

        (_outgoingAssets.assetAmounts, _incomingAssets.assetAmounts) =
            _postProcessCall(_vaultAddress, adapter, _outgoingAssets, _incomingAssets);
    }

    function _performCall(
        address _vaultAddress,
        address _adapter,
        bytes4 _selector,
        bytes memory _actionData,
        bytes memory _assetData
    ) private {
        (bool success, bytes memory returnData) =
            _adapter.call(abi.encodeWithSelector(_selector, _vaultAddress, _actionData, _assetData));
        require(success, string(returnData));
    }

    /// @dev Helper to get the vault's balance of a particular asset
    function _getVaultAssetBalance(address _vaultAddress, address _asset) private view returns (uint256) {
        return ERC20(_asset).balanceOf(_vaultAddress);
    }

    /// @dev Helper for the internal actions to take prior to executing CoI

    function _preProcessCall(address _vaultAddress, address _adapter, bytes4 _selector, bytes memory _adapterData)
        private
        returns (actionAssetsData memory incomingAssets_, actionAssetsData memory outgoingAssets_)
    {
        // Note that incoming and outgoing assets are allowed to overlap
        // (e.g., a fee for the incomingAsset charged in a outgoing asset)
        (
            incomingAssets_, //switch?
            outgoingAssets_
        ) = IAdapter(_adapter).parseAssetsForAction(_vaultAddress, _selector, _adapterData);

        // Check if inputs are correct
        require(
            incomingAssets_.assets.length == incomingAssets_.limitAssetAmounts.length,
            "IM: Incoming assets arrays unequal"
        );

        require(
            outgoingAssets_.assets.length == outgoingAssets_.limitAssetAmounts.length,
            "IM: Outgoing assets arrays unequal"
        );

        require(incomingAssets_.assets.length == incomingAssets_.assetIds.length, "IM: Incoming assets arrays unequal");
        require(outgoingAssets_.assets.length == outgoingAssets_.assetIds.length, "IM: Outgoing assets arrays unequal");

        // INCOMING ASSETS

        // Check if incoming assets are Arcadia whitelisted assets
        require(
            IMainRegistry(MAIN_REGISTRY).batchIsWhiteListed(incomingAssets_.assets, incomingAssets_.assetIds),
            "IM: Non-whitelisted incoming asset"
        );

        incomingAssets_.preCallAssetBalances = new uint256[](
            incomingAssets_.assets.length
        );

        for (uint256 i; i < incomingAssets_.assets.length; i++) {
            // Save all incoming asset balances preCall
            incomingAssets_.preCallAssetBalances[i] = ERC20(incomingAssets_.assets[i]).balanceOf(_vaultAddress);
        }

        // OUTGOING ASSETS

        outgoingAssets_.preCallAssetBalances = new uint256[](
            outgoingAssets_.assets.length
        );
        for (uint256 i; i < outgoingAssets_.assets.length; i++) {
            // Save all outgoing asset balances preCall
            outgoingAssets_.preCallAssetBalances[i] = ERC20(outgoingAssets_.assets[i]).balanceOf(_vaultAddress);

            // Approve vault assets
            IVault(_vaultAddress).approveAssetForAdapter(_adapter, outgoingAssets_.assets[i], outgoingAssets_.limitAssetAmounts[i]);
        }

        return (incomingAssets_, outgoingAssets_);
    }

    /// @dev Helper to reconcile incoming and spend assets after executing CoI
    function _postProcessCall(
        address _vaultAddress,
        address _adapter,
        actionAssetsData memory outgoingAssets_,
        actionAssetsData memory incomingAssets_
    ) private view returns (uint256[] memory incomingAssetAmounts_, uint256[] memory outgoingAssetAmounts_) {

        //INCOMING ASSETS

        incomingAssetAmounts_ = new uint256[](incomingAssets_.assets.length);
        for (uint256 i; i < incomingAssets_.assets.length; i++) {
            incomingAssetAmounts_[i] = _getVaultAssetBalance(_vaultAddress, incomingAssets_.assets[i])
                - incomingAssets_.preCallAssetBalances[i]; //TODO check overflow?

            // Check incoming assets are as expected
            require(
                incomingAssetAmounts_[i] >= incomingAssets_.limitAssetAmounts[i],
                "IM: Received incoming asset less than expected"
            );
        }
        // OUTGOING ASSETS

        outgoingAssetAmounts_ = new uint256[](outgoingAssets_.assets.length);
        for (uint256 i; i < outgoingAssets_.assets.length; i++) {
            // Calculate the balance change of spend assets. Ignore if balance increased.
            uint256 postCallAssetBalance = _getVaultAssetBalance(_vaultAddress, outgoingAssets_.assets[i]);
            if (postCallAssetBalance < outgoingAssets_.preCallAssetBalances[i]) {
                outgoingAssetAmounts_[i] = outgoingAssets_.preCallAssetBalances[i] - postCallAssetBalance;
            }

            // Check outgoing assets are as expected
            require(
                    outgoingAssetAmounts_[i] <= outgoingAssets_.limitAssetAmounts[i],
                    "IM: Outgoing amount greater than expected"
                );

            //TODO Reset any unused approvals
            //TODO make sure assets are withdrawn to vault in case they got tx'd to adapter.
            //TODO check coll thresh after swap.
        }

        // uint256 collThresh = IVault(_vaultAddress).getCollateralValue();
                // require(
                // //     outgoingAssetAmounts_[i] <= outgoingAssets_.limitAssetAmounts[i],
                // //     "IM: Outgoing amount greater than expected"
                // // );

        return (incomingAssetAmounts_, outgoingAssetAmounts_);
    }

    // Whitelist adapters

    function addWhitelist(address newAdapterAddress) public onlyOwner {
        adapterWhitelist[newAdapterAddress] = true;
    }

    function removeWhitelist(address newAdapterAddress) public onlyOwner {
        adapterWhitelist[newAdapterAddress] = false;
    }
}
