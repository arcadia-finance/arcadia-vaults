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
            address[] memory path,
            uint256 outgoingAssetAmount,
            uint256 minIncomingAssetAmount
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
            address actionAddress,
            uint256 actionAmount,
        )
    {
        require(_selector == bytes4(keccak256("_selector(address,bytes,bytes)")), "parseAssetsForAction: _selector invalid");

        return __parseAssetsForSelector(_actionData);
    }

    function __parseAssetsForSelector(bytes calldata _actionData)
        private
        pure
        returns (
            address actionAddress,
            uint256 actionAmount,
        )
    {
        (
            address actionAddress_,
            uint256 actionAmount_,
        ) = __decodeSelectorCallArgs(_actionData);

        return (
            actionAddress_,
            actionAmount_,
        );
    }

     function __decodeSelectorCallArgs(bytes memory _actionData)
        private
        pure
        returns (
            address actionAddress,
            uint256 actionAmount,
        )
    {
        return abi.decode(_actionData, (address, uint256));
    }
}
