/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IMainRegistry {
    function addAsset(address, uint256[] memory) external;

    function getTotalValue(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        uint256 numeraire
    ) external view returns (uint256);

    function factoryAddress() external view returns (address);

    function numeraireToInformation(uint256 numeraire)
        external
        view
        returns (
            uint64,
            uint64,
            address,
            address,
            address,
            string memory
        );
}
