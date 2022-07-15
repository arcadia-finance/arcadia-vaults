/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {FixedPointMathLib} from "./FixedPointMathLib.sol";

interface IFacts {
    function allVaultsLength() external view returns (uint256);
    function allVaults(uint256) external view returns (address);
    function numeraireCounter() external view returns (uint256);
    function vaultIndex(address) external view returns (uint256);
}

interface IMainRegs {
    function getOracleForNumeraire(uint256) external view returns (address);
    function getListOfValuesPerAsset(address[] memory, uint256[] memory, uint256[] memory, uint256) external view returns (uint256[] memory);
    function getListOfValuesPerCreditRating(
        address[] memory,
        uint256[] memory,
        uint256[] memory,
        uint256 numeraire
    ) external view returns (uint256[] memory);
}

interface IOracleHubs {
   function getRate(address[] memory, uint256) external view returns (uint256, uint256);
}

interface IVaults {
    struct debtInfo {
        uint128 _openDebt;
        uint16 _collThres; //2 decimals precision (factor 100)
        uint8 _liqThres; //2 decimals precision (factor 100)
        uint64 _yearlyInterestRate; //18 decimals precision (factor 10**18)
        uint32 _lastBlock;
        uint8 _numeraire;
    }

    function debt() external view returns (debtInfo memory);
    function getValue(uint8) external view returns (uint256);
    function owner() external view returns (address);
    function life() external view returns (uint256);
    function getOpenDebt() external view returns (uint256);
    function generateAssetData() external view returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts
        );
    function _registryAddress() external view returns (address);
    function _irmAddress() external view returns (address);
}

interface IRM_H {
    function creditRatingToInterestRate(uint256) external view returns (uint256);
    function baseInterestRate() external view returns (uint256);
}

contract beHelper {

    using FixedPointMathLib for uint256;
    struct ReturnInfo {
        address vaultAddress;
        address vaultOwner;
        uint256 vaultValueNumeraire;
        uint256 vaultDebt;
        uint256 vaultNumeraire;
        uint256 vaultLife;
        uint256 vaultId;
    }

    function _getNumeraireToUsdRate(address[] memory oracles, address oracleHub) public view returns (uint256[] memory) {
        uint256[] memory numeraireToUsdRates = new uint256[](oracles.length);

        uint256 rate;
        address[] memory oracleAddress = new address[](1);

        for (uint i; i < oracles.length; ++i) {
            oracleAddress[0] = oracles[i];
            if (i == 0) {
                rate = 10**18;
            }
            else {
                (rate,) = IOracleHubs(oracleHub).getRate(oracleAddress, i);
            }

            numeraireToUsdRates[i] = rate;
        }

        return numeraireToUsdRates;
    }

    function getNumeraireToUsdRates(address factory, address mainreg, address oracleHub) external view returns (uint256[] memory) {
        IFacts factoryInterface = IFacts(factory);

        uint256 numeraireCounter = factoryInterface.numeraireCounter();
        address[] memory numeraireOracleAddresses = new address[](numeraireCounter);

        for (uint i; i < numeraireCounter; ++i) {
            numeraireOracleAddresses[i] = IMainRegs(mainreg).getOracleForNumeraire(i);
        }

        uint256[] memory rates = _getNumeraireToUsdRate(numeraireOracleAddresses, oracleHub);

        return rates;
    }

    function getItAll(address factory) external view returns (ReturnInfo[] memory) {

        uint256 vaultLen = IFacts(factory).allVaultsLength();

        address tempVault;
        IVaults.debtInfo memory tempInfo;
        address tempOwner;
        uint256 tempLife;
        uint256 tempVaultValueNumeraire;
        uint256 tempVaultDebt;

        ReturnInfo[] memory returnInfo = new ReturnInfo[](vaultLen);

        for (uint i; i < vaultLen; i++) {
            tempVault = IFacts(factory).allVaults(i);
            tempInfo = IVaults(tempVault).debt();
            tempOwner = IVaults(tempVault).owner();

            tempVaultValueNumeraire = IVaults(tempVault).getValue(tempInfo._numeraire);
            tempVaultDebt = IVaults(tempVault).getOpenDebt();

            tempLife = IVaults(tempVault).life();

            returnInfo[i] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueNumeraire: tempVaultValueNumeraire, 
                                        vaultDebt: tempVaultDebt, 
                                        vaultLife: tempLife, 
                                        vaultNumeraire: tempInfo._numeraire,
                                        vaultId: i});
        }

        return returnInfo;


    }

    function getItAllForOneOwner(address factory, address fetchForOwner) external view returns (ReturnInfo[] memory) {

        uint256 vaultLen = IFacts(factory).allVaultsLength();
        uint256 tempVaultValueNumeraire;

        address tempVault;
        IVaults.debtInfo memory tempInfo;
        address tempOwner;
        uint256 tempLife;
        uint256 tempVaultDebt;

        uint256 lenCounter = 0;
        ReturnInfo[] memory returnInfo = new ReturnInfo[](vaultLen);
        for (uint i; i < vaultLen; i++) {
            tempVault = IFacts(factory).allVaults(i);
            tempOwner = IVaults(tempVault).owner();

            if (tempOwner != fetchForOwner) continue;

            tempInfo = IVaults(tempVault).debt();
            tempVaultDebt = IVaults(tempVault).getOpenDebt();

            tempVaultValueNumeraire = IVaults(tempVault).getValue(tempInfo._numeraire);

            tempLife = IVaults(tempVault).life();

            returnInfo[lenCounter] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueNumeraire: tempVaultValueNumeraire,
                                        vaultDebt: tempVaultDebt, 
                                        vaultLife: tempLife, 
                                        vaultNumeraire: tempInfo._numeraire,
                                        vaultId: i});
            unchecked {lenCounter++;}
        }

        return returnInfo;

    }


    function getItAllForVaults(address factory, address[] calldata fetchForVault) external view returns (ReturnInfo[] memory) {

        uint256 tempVaultValueNumeraire;

        address tempVault;
        IVaults.debtInfo memory tempInfo;
        address tempOwner;
        uint256 tempLife;
        uint256 tempVaultId;
        uint256 tempVaultDebt;

        ReturnInfo[] memory returnInfo = new ReturnInfo[](fetchForVault.length);
        for (uint i; i < fetchForVault.length; i++) {
            tempVault = IFacts(factory).allVaults(i);
            tempInfo = IVaults(tempVault).debt();
            tempVaultDebt = IVaults(tempVault).getOpenDebt();
            tempOwner = IVaults(tempVault).owner();
            tempVaultValueNumeraire = IVaults(tempVault).getValue(tempInfo._numeraire);

            tempLife = IVaults(tempVault).life();
            tempVaultId = IFacts(factory).vaultIndex(tempVault);

            returnInfo[i] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueNumeraire: tempVaultValueNumeraire,
                                        vaultDebt: tempVaultDebt, 
                                        vaultLife: tempLife, 
                                        vaultNumeraire: tempInfo._numeraire,
                                        vaultId: tempVaultId});
        }

        return returnInfo;

    }


    struct Overview {
        address[] assetAddresses;
        uint256[] assetIds;
        uint256[] assetAmounts;
        uint256[] valuesPerAsset;
        uint256[] valuesPerCreditRating;
        uint256 vaultDebt;
        uint256 vaultValue;
        uint256 interestRate;
    }

    function _getVaultOverview(address vault, address mainReg, address irm) public view 
           returns (Overview memory overview, IVaults.debtInfo memory tempInfo) 
    {


        (
            overview.assetAddresses,
            overview.assetIds,
            overview.assetAmounts
        ) = IVaults(vault).generateAssetData();


        tempInfo = IVaults(vault).debt();

        overview.valuesPerAsset = IMainRegs(mainReg).getListOfValuesPerAsset(overview.assetAddresses, overview.assetIds, overview.assetAmounts, tempInfo._numeraire);
        overview.valuesPerCreditRating = IMainRegs(mainReg).getListOfValuesPerCreditRating(overview.assetAddresses, overview.assetIds, overview.assetAmounts, tempInfo._numeraire);
        overview.vaultDebt = IVaults(vault).getOpenDebt();

        overview.vaultValue = IVaults(vault).getValue(uint8(tempInfo._numeraire));
        uint256 minCollValue;

        unchecked {
            minCollValue =
                uint256((overview.vaultDebt) * tempInfo._collThres) / 100;
        }

        overview.interestRate = IRM_H(irm).baseInterestRate() + calculateWeightedCollateralInterestrate(overview.valuesPerCreditRating, minCollValue, irm);

        return (overview, tempInfo);

    }

     function getVaultOverview(address vault, address mainReg, address irm) public view 
            returns (address[] memory, 
                    uint256[] memory, 
                    uint256[] memory,
                    uint256[] memory,
                    uint256[] memory,
                    uint256[] memory) {

        (Overview memory overview, IVaults.debtInfo memory tempInfo) = _getVaultOverview(vault, mainReg, irm);


        uint256[] memory returnList = new uint256[](8);
        returnList[0] = overview.vaultDebt;
        returnList[1] = overview.vaultValue;
        returnList[2] = overview.interestRate;
        returnList[3] = tempInfo._collThres;
        returnList[4] = tempInfo._liqThres;
        returnList[5] = tempInfo._yearlyInterestRate;
        returnList[6] = tempInfo._lastBlock;
        returnList[7] = tempInfo._numeraire;


        return (overview.assetAddresses,
                overview.assetIds,
                overview.assetAmounts,
                overview.valuesPerAsset,
                overview.valuesPerCreditRating,
                returnList);

     }


    function calculateWeightedCollateralInterestrate(
        uint256[] memory valuesPerCreditRating,
        uint256 minCollValue,
        address IrmAddr
    ) public view returns (uint256) {
        if (minCollValue == 0) {
            return 0;
        } else {
            uint256 collateralInterestRate;
            uint256 totalValue;
            uint256 value;
            uint256 valuesPerCreditRatingLength = valuesPerCreditRating.length;
            //Start from Category 1 (highest quality assets)
            for (uint256 i = 1; i < valuesPerCreditRatingLength; ) {
                value = valuesPerCreditRating[i];
                if (totalValue + value < minCollValue) {
                    collateralInterestRate += IRM_H(IrmAddr).creditRatingToInterestRate(i)
                        .mulDivDown(value, minCollValue);
                    totalValue += value;
                } else {
                    value = minCollValue - totalValue;
                    collateralInterestRate += IRM_H(IrmAddr).creditRatingToInterestRate(i)
                        .mulDivDown(value, minCollValue);
                    return collateralInterestRate;
                }
                unchecked {
                    ++i;
                }
            }
            //Loop ended without returning -> use lowest credit rating (at index 0) for remaining collateral
            value = minCollValue - totalValue;
            collateralInterestRate += IRM_H(IrmAddr).creditRatingToInterestRate(0).mulDivDown(
                value,
                minCollValue
            );

            return collateralInterestRate;
        }
    }


}