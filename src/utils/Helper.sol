/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

interface IFacts {
    function allVaultsLength() external view returns (uint256);
    function allVaults(uint256) external view returns (address);
    function numeraireCounter() external view returns (uint256);
    function vaultIndex(address) external view returns (uint256);
}

interface IMainRegs {
    function getOracleForNumeraire(uint256) external view returns (address);
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
}

contract getValues {

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

        uint256 lenCounter = 0;
        ReturnInfo[] memory returnInfo = new ReturnInfo[](vaultLen);
        for (uint i; i < vaultLen; i++) {
            tempVault = IFacts(factory).allVaults(i);
            tempOwner = IVaults(tempVault).owner();

            if (tempOwner != fetchForOwner) continue;

            tempInfo = IVaults(tempVault).debt();

            tempVaultValueNumeraire = IVaults(tempVault).getValue(tempInfo._numeraire);

            tempLife = IVaults(tempVault).life();

            returnInfo[lenCounter] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueNumeraire: tempVaultValueNumeraire,
                                        vaultDebt: tempInfo._openDebt, 
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

        ReturnInfo[] memory returnInfo = new ReturnInfo[](fetchForVault.length);
        for (uint i; i < fetchForVault.length; i++) {
            tempVault = IFacts(factory).allVaults(i);
            tempInfo = IVaults(tempVault).debt();
            tempOwner = IVaults(tempVault).owner();
            tempVaultValueNumeraire = IVaults(tempVault).getValue(tempInfo._numeraire);

            tempLife = IVaults(tempVault).life();
            tempVaultId = IFacts(factory).vaultIndex(tempVault);

            returnInfo[i] = ReturnInfo({vaultAddress: tempVault, 
                                        vaultOwner: tempOwner, 
                                        vaultValueNumeraire: tempVaultValueNumeraire,
                                        vaultDebt: tempInfo._openDebt, 
                                        vaultLife: tempLife, 
                                        vaultNumeraire: tempInfo._numeraire,
                                        vaultId: tempVaultId});
        }

        return returnInfo;

    }


}