// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

interface IMainReg {
    function assetToBaseCurrencyToCreditRating(address asset, uint256 baseCurrency)
        external
        view
        returns (uint256);
}

contract TestCompiler {
    function MRGetAssetToBaseCurrencyToCreditRating(
        address mainRegAddr,
        address[] calldata assets,
        uint256[] calldata baseCurrencys
    ) public view returns (uint256[] memory) {
        uint256[] memory ratings = new uint256[](assets.length);

        for (uint256 i; i < assets.length; i++) {
            ratings[i] = IMainReg(mainRegAddr).assetToBaseCurrencyToCreditRating(
                assets[i],
                baseCurrencys[i]
            );
        }

        return ratings;
    }
}
