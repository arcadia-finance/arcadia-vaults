// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

// interfaces
import "../Integrations/AdapterBase.sol";

contract AdapterMock is AdapterBase {

   constructor(address _integrationManager)
        public
        AdapterBase(_integrationManager)
    {}


    //Make this 
    function _selector(
        address _vaultProxy,
        bytes calldata _actionData,
        bytes calldata
    ) external onlyIntegrationManager {
        (
            address[] memory path,
            uint256 outgoingAssetAmount,
            uint256 minIncomingAssetAmount
        ) = __decodeTakeOrderCallArgs(_actionData);
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
        require(_selector == TAKE_ORDER_SELECTOR, "parseAssetsForAction: _selector invalid");

        return __parseAssetsForTakeOrder(_actionData);
    }

    function __parseAssetsForTakeOrder(bytes calldata _actionData)
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
            address[] memory path,
            uint256 outgoingAssetAmount,
            uint256 minIncomingAssetAmount
        ) = __decodeTakeOrderCallArgs(_actionData);

        require(path.length >= 2, "__parseAssetsForTakeOrder: _path must be >= 2");

        spendAssets_ = new address[](1);
        spendAssets_[0] = path[0];
        spendAssetAmounts_ = new uint256[](1);
        spendAssetAmounts_[0] = outgoingAssetAmount;

        incomingAssets_ = new address[](1);
        incomingAssets_[0] = path[path.length - 1];
        minIncomingAssetAmounts_ = new uint256[](1);
        minIncomingAssetAmounts_[0] = minIncomingAssetAmount;

        return (
            spendAssets_,
            spendAssetAmounts_,
            incomingAssets_,
            minIncomingAssetAmounts_
        );
    }

     function __decodeTakeOrderCallArgs(bytes memory _actionData)
        private
        pure
        returns (
            address[] memory path_,
            uint256 outgoingAssetAmount_,
            uint256 minIncomingAssetAmount_
        )
    {
        return abi.decode(_actionData, (address[], uint256, uint256));
    }
}
