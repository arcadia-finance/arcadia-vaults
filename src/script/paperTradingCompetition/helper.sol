/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;


interface IReg {
    function getWhiteList() external view returns (address[] memory);
    function assetToSubRegistry(address) external view returns (address);
    function getTotalValue(
                        address[] calldata, 
                        uint256[] calldata,
                        uint256[] calldata,
                        uint256 numeraire
                      ) external view returns (uint256);
}

interface ISubReg20 {
    struct AssetInformation {
        uint64 assetUnit;
        address assetAddress;
        address[] oracleAddresses;
    }
    function getAssetInformation(address asset) external view returns (uint64, address, address[] memory);
}

interface ISubReg721 {
    struct AssetInformation {
        uint256 idRangeStart;
        uint256 idRangeEnd;
        address assetAddress;
        address[] oracleAddresses;
    }
    function getAssetInformation(address) external view returns (uint256, uint256, address, address[] memory);
}

interface IERC {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

contract HelperContract {
    address public owner;
    HelperAddresses public helperAddresses;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    struct HelperAddresses {
        address factory;
        address vaultLogic;
        address mainReg;
        address erc20sub;
        address erc721sub;
        address oracleHub;
        address irm;
        address liquidator;
        address stableUsd;
        address stableEth;
        address weth;
        address tokenShop;
    }

    struct assetInfo {
        address assetAddr;
        uint256 assetUnits;
        address[] oracleAddresses;
        string description;
        string symbol;
        uint256 ratePerUnitUsd;
        uint256 ratePerUnitEth;
        uint256 assetType;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function storeAddresses(HelperAddresses calldata addrs) public onlyOwner {
        helperAddresses = addrs;
    }

    function getAllPrices() public view returns (HelperAddresses memory, assetInfo[] memory) {
        address[] memory whitelisted = IReg(helperAddresses.mainReg).getWhiteList();
        address subreg;
        assetInfo[] memory assetInfos = new assetInfo[](whitelisted.length);
        address[] memory assetAddrs = new address[](1);
        uint256[] memory assetIds = new uint256[](1);
        uint256[] memory assetAmts = new uint256[](1);

        uint64 tempAssetUnit;
        address tempAssetAddress;
        address[] memory tempOracleAddresses;

        for (uint256 i; i < whitelisted.length; i++) {
            assetInfo memory tempAssetInfo;
            tempAssetInfo.assetAddr = whitelisted[i];
            subreg = IReg(helperAddresses.mainReg).assetToSubRegistry(whitelisted[i]);

            if (subreg == helperAddresses.erc20sub) {
                (tempAssetUnit, tempAssetAddress, tempOracleAddresses) = ISubReg20(subreg).getAssetInformation(whitelisted[i]);
                tempAssetInfo.assetType = 0;
                tempAssetInfo.assetUnits = tempAssetUnit;
                tempAssetInfo.oracleAddresses = tempOracleAddresses;
                assetAddrs[0] = whitelisted[i];
                assetIds[0] = 0;
                assetAmts[0] = tempAssetUnit;

                tempAssetInfo.ratePerUnitUsd = IReg(helperAddresses.mainReg).getTotalValue(assetAddrs, assetIds, assetAmts, 0);
                tempAssetInfo.ratePerUnitEth = IReg(helperAddresses.mainReg).getTotalValue(assetAddrs, assetIds, assetAmts, 1);

            }
            else if (subreg == helperAddresses.erc721sub) {
                (,,,address[] memory oracleAddresses) = ISubReg721(subreg).getAssetInformation(whitelisted[i]);
                tempAssetInfo.assetType = 1;
                tempAssetInfo.oracleAddresses = oracleAddresses;
                assetAddrs[0] = whitelisted[i];
                assetIds[0] = 1;
                assetAmts[0] = 1;

                tempAssetInfo.ratePerUnitUsd = IReg(helperAddresses.mainReg).getTotalValue(assetAddrs, assetIds, assetAmts, 0);
                tempAssetInfo.ratePerUnitEth = IReg(helperAddresses.mainReg).getTotalValue(assetAddrs, assetIds, assetAmts, 1);
            }

            tempAssetInfo.description = IERC(whitelisted[i]).name();
            tempAssetInfo.symbol = IERC(whitelisted[i]).symbol();

            assetInfos[i] = tempAssetInfo;
        }

        return (helperAddresses, assetInfos);
    }

}
