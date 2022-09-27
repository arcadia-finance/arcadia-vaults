// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

// interfaces
import "../Integrations/AdapterCore.sol";

contract AdapterMock is AdapterCore {
    constructor(address _integrationManager) public AdapterCore(_integrationManager) {}

    function _selector(address _vaultProxy, bytes calldata _actionData, bytes calldata)
        external
        onlyIntegrationManager
    {
        (address actionAddress, uint256 actionAmount) = __decodeSelectorCallArgs(_actionData);

        //Call to external service here.
    }

    function parseAssetsForAction(address, bytes4 _selector, bytes calldata _actionData)
        external
        view
        override
        returns (actionAssetsData memory spendAssets_, actionAssetsData memory incomingAssets_)
    {
        require(
            _selector == bytes4(keccak256("_selector(address,bytes,bytes)")), "parseAssetsForAction: _selector invalid"
        );

        return __parseAssetsForSelector(_actionData);
    }

    function __parseAssetsForSelector(bytes calldata _actionData)
        private
        pure
        returns (actionAssetsData memory spendAssets_, actionAssetsData memory incomingAssets_)
    {
        (address actionAddress_, uint256 actionAmount_) = __decodeSelectorCallArgs(_actionData);

        spendAssets_.assets = new address[](1);
        spendAssets_.assets[0] = actionAddress_;
        spendAssets_.minmaxAssetAmounts = new uint256[](1);
        spendAssets_.minmaxAssetAmounts[0] = actionAmount_;

        incomingAssets_.assets = new address[](1);
        incomingAssets_.assets[0] = actionAddress_;
        incomingAssets_.minmaxAssetAmounts = new uint256[](1);
        incomingAssets_.minmaxAssetAmounts[0] = actionAmount_;

        return (spendAssets_, incomingAssets_);
    }

    function _decodeSelectorCallArgs(bytes memory _actionData)
        private
        pure
        returns (address actionAddress, uint256 actionAmount)
    {
        return abi.decode(_actionData, (address, uint256));
    }
}
