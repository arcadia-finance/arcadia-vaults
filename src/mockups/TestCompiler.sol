// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

interface IMainReg {
    function assetToNumeraireToCreditRating(address asset, uint256 numeraire)
        external
        view
        returns (uint256);
}

contract TestCompiler {
    function MRGetAssetToNumeraireToCreditRating(
        address mainRegAddr,
        address[] calldata assets,
        uint256[] calldata numeraires
    ) public view returns (uint256[] memory) {
        uint256[] memory ratings = new uint256[](assets.length);

        for (uint256 i; i < assets.length; i++) {
            ratings[i] = IMainReg(mainRegAddr).assetToNumeraireToCreditRating(
                assets[i],
                numeraires[i]
            );
        }

        return ratings;
    }
}
