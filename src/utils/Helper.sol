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
        uint256 vaultDebt;
        uint256 vaultNumeraire;
        uint256 vaultLife;
    }

    function getItAll(address factory) external view returns (ReturnInfo[] memory) {

        uint256 vaultLen = IFact(factory).allVaultsLength();

        address tempVault;
        IVault.debtInfo memory tempInfo;
        address tempOwner;
        uint256 tempValueUSD;
        uint256 tempValueETH;
        uint256 tempLife;
        ReturnInfo[] memory returnInfo = new ReturnInfo[](vaultLen);

        for (uint i; i < vaultLen; i++) {
            tempVault = IFact(factory).allVaults(i);
            tempInfo = IVault(tempVault).debt();
            tempOwner = IVault(tempVault).owner();
            tempValueUSD = IVault(tempVault).getValue(uint8(0));
            tempValueETH = IVault(tempVault).getValue(uint8(1));
            tempLife = IVault(tempVault).life();

            returnInfo[i] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueUSD: tempValueUSD, 
                                        vaultValueETH: tempValueETH, 
                                        vaultDebt: tempInfo._openDebt, 
                                        vaultLife: tempLife, 
                                        vaultNumeraire: tempInfo._numeraire});
        }

        return returnInfo;


    }

        function getItAllForOneOwner(address factory, address fetchForOwner) external view returns (ReturnInfo[] memory) {

        uint256 vaultLen = IFact(factory).allVaultsLength();

        address tempVault;
        IVault.debtInfo memory tempInfo;
        address tempOwner;
        uint256 tempValueUSD;
        uint256 tempValueETH;
        uint256 tempLife;

        ReturnInfo[] memory returnInfo = new ReturnInfo[](vaultLen);
        for (uint i; i < vaultLen; i++) {
            tempVault = IFact(factory).allVaults(i);
            tempOwner = IVault(tempVault).owner();

            if (tempOwner != fetchForOwner) continue;

            tempInfo = IVault(tempVault).debt();

            tempValueUSD = IVault(tempVault).getValue(uint8(0));
            tempValueETH = IVault(tempVault).getValue(uint8(1));
            tempLife = IVault(tempVault).life();

            returnInfo[i] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueUSD: tempValueUSD, 
                                        vaultValueETH: tempValueETH, 
                                        vaultDebt: tempInfo._openDebt, 
                                        vaultLife: tempLife, 
                                        vaultNumeraire: tempInfo._numeraire});
        }

        return returnInfo;

    }


        function getItAllForVaults(address factory, address[] calldata fetchForVault) external view returns (ReturnInfo[] memory) {

        address tempVault;
        IVault.debtInfo memory tempInfo;
        address tempOwner;
        uint256 tempValueUSD;
        uint256 tempValueETH;
        uint256 tempLife;

        ReturnInfo[] memory returnInfo = new ReturnInfo[](fetchForVault.length);
        for (uint i; i < fetchForVault.length; i++) {
            tempVault = IFact(factory).allVaults(i);
            tempInfo = IVault(tempVault).debt();
            tempOwner = IVault(tempVault).owner();
            tempValueUSD = IVault(tempVault).getValue(uint8(0));
            tempValueETH = IVault(tempVault).getValue(uint8(1));
            tempLife = IVault(tempVault).life();

            returnInfo[i] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueUSD: tempValueUSD, 
                                        vaultValueETH: tempValueETH, 
                                        vaultDebt: tempInfo._openDebt, 
                                        vaultLife: tempLife, 
                                        vaultNumeraire: tempInfo._numeraire});
        }

        return returnInfo;

    }


}