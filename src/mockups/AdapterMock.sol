// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

// interfaces
import "../Integrations/AdapterBase.sol";

contract AdapterMock is AdapterBase {

   constructor(address _integrationManager)
        public
        AdapterBase(_integrationManager)
    {}

    function _selector(
        address _vaultProxy,
        bytes calldata _actionData,
        bytes calldata
    ) external onlyIntegrationManager {
        (
            address actionAddress,
            uint256 actionAmount
        ) = __decodeSelectorCallArgs(_actionData);
    }
    function parseAssetsForAction(
        address,
        bytes4 _selector,
        bytes calldata _actionData
    )
        external
        view
        override
        returns (
            address[] memory spendAssets_,
            uint256[] memory spendAssetAmounts_,
            address[] memory incomingAssets_,
            uint256[] memory minIncomingAssetAmounts_
        )
    {
        require(_selector == bytes4(keccak256("_selector(address,bytes,bytes)")), "parseAssetsForAction: _selector invalid");

        return __parseAssetsForSelector(_actionData);
    }

    function __parseAssetsForSelector(bytes calldata _actionData)
        private
        pure
        returns (
            address[] memory spendAssets_,
            uint256[] memory spendAssetAmounts_,
            address[] memory incomingAssets_,
            uint256[] memory minIncomingAssetAmounts_
        )
    {
        (
            address actionAddress_,
            uint256 actionAmount_
        ) = __decodeSelectorCallArgs(_actionData);

        spendAssets_ = new address[](1);
        spendAssets_[0] = actionAddress_;
        spendAssetAmounts_ = new uint256[](1);
        spendAssetAmounts_[0] = actionAmount_;

        incomingAssets_ = new address[](1);
        incomingAssets_[0] = actionAddress_;
        minIncomingAssetAmounts_ = new uint256[](1);
        minIncomingAssetAmounts_[0] = actionAmount_;


        return (
            spendAssets_,
            spendAssetAmounts_,
            incomingAssets_,
            minIncomingAssetAmounts_
        );
    }

     function __decodeSelectorCallArgs(bytes memory _actionData)
        private
        pure
        returns (
            address actionAddress,
            uint256 actionAmount
        )
    {
        return abi.decode(_actionData, (address, uint256));
    }
}
