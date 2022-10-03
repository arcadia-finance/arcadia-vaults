// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

// interfaces
import "../Integrations/AdapterCore.sol";

contract AdapterMock is AdapterCore {
    constructor(address _integrationManager) public AdapterCore(_integrationManager) {}

    function _selector(address _vaultAddress, bytes calldata _actionData, bytes calldata)
        external
        onlyIntegrationManager
    {
        (address actionAddress, uint256 actionAmount) = _decodeSelectorCallArgs(_actionData);

        //Call to external service here.
    }

    function parseAssetsForAction(address, bytes4 _selector, bytes calldata _actionData)
        external
        view
        override
        returns (actionAssetsData memory _outgoingAssets, actionAssetsData memory _incomingAssets)
    {
        require(
            _selector == bytes4(keccak256("_selector(address,bytes,bytes)")), "parseAssetsForAction: _selector invalid"
        );

        return _parseAssetsForSelector(_actionData);
    }

    function _parseAssetsForSelector(bytes calldata _actionData)
        private
        pure
        returns (actionAssetsData memory outgoingAssets_, actionAssetsData memory incomingAssets_)
    {
        (address actionAddress_, uint256 actionAmount_) = _decodeSelectorCallArgs(_actionData);

        outgoingAssets_.assets = new address[](1);
        outgoingAssets_.assets[0] = actionAddress_;
        outgoingAssets_.limitAssetAmounts = new uint256[](1);
        outgoingAssets_.limitAssetAmounts[0] = actionAmount_;

        incomingAssets_.assets = new address[](1);
        incomingAssets_.assets[0] = actionAddress_;
        incomingAssets_.limitAssetAmounts = new uint256[](1);
        incomingAssets_.limitAssetAmounts[0] = actionAmount_;

        return (outgoingAssets_, incomingAssets_);
    }

    function _decodeSelectorCallArgs(bytes memory _actionData)
        private
        pure
        returns (address actionAddress, uint256 actionAmount)
    {
        return abi.decode(_actionData, (address, uint256));
    }
}
