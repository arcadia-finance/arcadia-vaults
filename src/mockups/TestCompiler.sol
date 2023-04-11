// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IMainReg {
    function collateralFactors(address asset, uint256 baseCurrency) external view returns (uint16);
}

contract TestCompiler {
    function MRGetAssetToBaseCurrencyToCollateralFactor(
        address mainRegAddr,
        address[] calldata assets,
        uint256[] calldata baseCurrencies
    ) public view returns (uint16[] memory) {
        uint16[] memory collateralFactors = new uint16[](assets.length);

        for (uint256 i; i < assets.length; i++) {
            collateralFactors[i] = IMainReg(mainRegAddr).collateralFactors(assets[i], baseCurrencies[i]);
        }

        return collateralFactors;
    }
}
