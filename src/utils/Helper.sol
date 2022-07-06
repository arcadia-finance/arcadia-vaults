/** 
    This is a private, unpublished repository.
    All rights reserved to Arcadia Finance.
    Any modification, publication, reproduction, commercialization, incorporation, 
    sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
    
    SPDX-License-Identifier: UNLICENSED
 */
pragma solidity ^0.8.13;

interface IFact {
    function allVaultsLength() external view returns (uint256);
    function allVaults(uint256) external view returns (address);
    function numeraireCounter() external view returns (uint256);
    function vaultIndex(address) external view returns (uint256);
}

interface IVault {
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
}

contract getValues {

    struct ReturnInfo {
        address vaultAddress;
        address vaultOwner;
        uint256 vaultValueUSD;
        uint256 vaultValueETH;
        uint256 vaultValue2;
        uint256 vaultValue3;
        uint256 vaultDebt;
        uint256 vaultNumeraire;
        uint256 vaultLife;
        uint256 vaultId;
    }

    function getItAll(address factory) external view returns (ReturnInfo[] memory) {

        uint256 vaultLen = IFact(factory).allVaultsLength();
        uint256 numeraireCounter = IFact(factory).numeraireCounter();

        address tempVault;
        IVault.debtInfo memory tempInfo;
        address tempOwner;
        uint256 tempLife;
        uint256 tempVaultValueUSD;
        uint256 tempVaultValueETH;
        uint256 tempVaultValue2;
        uint256 tempVaultValue3;

        ReturnInfo[] memory returnInfo = new ReturnInfo[](vaultLen);

        for (uint i; i < vaultLen; i++) {
            tempVault = IFact(factory).allVaults(i);
            tempInfo = IVault(tempVault).debt();
            tempOwner = IVault(tempVault).owner();

            tempVaultValueUSD = IVault(tempVault).getValue(0);
            tempVaultValueETH = IVault(tempVault).getValue(1);

            if (numeraireCounter > 2) {
                tempVaultValue2 = IVault(tempVault).getValue(2);
            }
            if (numeraireCounter > 3) {
                tempVaultValue3 = IVault(tempVault).getValue(3);
            }

            tempLife = IVault(tempVault).life();

            returnInfo[i] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueUSD: tempVaultValueUSD, 
                                        vaultValueETH: tempVaultValueETH, 
                                        vaultValue2: tempVaultValue2, 
                                        vaultValue3: tempVaultValue3, 
                                        vaultDebt: tempInfo._openDebt, 
                                        vaultLife: tempLife, 
                                        vaultNumeraire: tempInfo._numeraire,
                                        vaultId: i});
        }

        return returnInfo;


    }

    function getItAllForOneOwner(address factory, address fetchForOwner) external view returns (ReturnInfo[] memory) {

        uint256 vaultLen = IFact(factory).allVaultsLength();
        uint256 numeraireCounter = IFact(factory).numeraireCounter();
        uint256 tempVaultValueUSD;
        uint256 tempVaultValueETH;
        uint256 tempVaultValue2;
        uint256 tempVaultValue3;

        address tempVault;
        IVault.debtInfo memory tempInfo;
        address tempOwner;
        uint256 tempLife;

        uint256 lenCounter = 0;
        ReturnInfo[] memory returnInfo = new ReturnInfo[](vaultLen);
        for (uint i; i < vaultLen; i++) {
            tempVault = IFact(factory).allVaults(i);
            tempOwner = IVault(tempVault).owner();

            if (tempOwner != fetchForOwner) continue;

            tempInfo = IVault(tempVault).debt();

            tempVaultValueUSD = IVault(tempVault).getValue(0);
            tempVaultValueETH = IVault(tempVault).getValue(1);

            if (numeraireCounter > 2) {
                tempVaultValue2 = IVault(tempVault).getValue(2);
            }
            if (numeraireCounter > 3) {
                tempVaultValue3 = IVault(tempVault).getValue(3);
            }
            tempLife = IVault(tempVault).life();

            returnInfo[lenCounter] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueUSD: tempVaultValueUSD, 
                                        vaultValueETH: tempVaultValueETH, 
                                        vaultValue2: tempVaultValue2, 
                                        vaultValue3: tempVaultValue3,
                                        vaultDebt: tempInfo._openDebt, 
                                        vaultLife: tempLife, 
                                        vaultNumeraire: tempInfo._numeraire,
                                        vaultId: i});
            unchecked {lenCounter++;}
        }

        return returnInfo;

    }


    function getItAllForVaults(address factory, address[] calldata fetchForVault) external view returns (ReturnInfo[] memory) {

        uint256 numeraireCounter = IFact(factory).numeraireCounter();
        uint256 tempVaultValueUSD;
        uint256 tempVaultValueETH;
        uint256 tempVaultValue2;
        uint256 tempVaultValue3;

        address tempVault;
        IVault.debtInfo memory tempInfo;
        address tempOwner;
        uint256 tempLife;
        uint256 tempVaultId;

        ReturnInfo[] memory returnInfo = new ReturnInfo[](fetchForVault.length);
        for (uint i; i < fetchForVault.length; i++) {
            tempVault = IFact(factory).allVaults(i);
            tempInfo = IVault(tempVault).debt();
            tempOwner = IVault(tempVault).owner();
            tempVaultValueUSD = IVault(tempVault).getValue(0);
            tempVaultValueETH = IVault(tempVault).getValue(1);

            if (numeraireCounter > 2) {
                tempVaultValue2 = IVault(tempVault).getValue(2);
            }
            if (numeraireCounter > 3) {
                tempVaultValue3 = IVault(tempVault).getValue(3);
            }
            tempLife = IVault(tempVault).life();
            tempVaultId = IFact(factory).vaultIndex(tempVault);

            returnInfo[i] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueUSD: tempVaultValueUSD, 
                                        vaultValueETH: tempVaultValueETH, 
                                        vaultValue2: tempVaultValue2, 
                                        vaultValue3: tempVaultValue3, 
                                        vaultDebt: tempInfo._openDebt, 
                                        vaultLife: tempLife, 
                                        vaultNumeraire: tempInfo._numeraire,
                                        vaultId: tempVaultId});
        }

        return returnInfo;

    }


}