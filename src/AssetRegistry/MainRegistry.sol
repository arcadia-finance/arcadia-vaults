/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../interfaces/IChainLinkData.sol";
import "../interfaces/IOraclesHub.sol";
import "../interfaces/IFactory.sol";
import "../interfaces/IPricingModule.sol";

import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";
import {RiskModule} from "../RiskModule.sol";

/**
 * @title Main Asset registry
 * @author Arcadia Finance
 * @notice The Main-registry stores basic information for each token that can, or could at some point, be deposited in the vaults
 * @dev No end-user should directly interact with the Main-registry, only vaults, Sub-Registries or the contract owner
 */
contract MainRegistry is Ownable {
    using FixedPointMathLib for uint256;

    address immutable _this;

    bool public assetsUpdatable = true;

    uint256 public baseCurrencyCounter;

    address public factoryAddress;

    address[] private pricingModules;
    address[] public assetsInMainRegistry;
    address[] public baseCurrencies;

    mapping(address => bool) public inMainRegistry;
    mapping(address => bool) public isPricingModule;
    mapping(address => bool) public isBaseCurrency;
    mapping(address => uint256) public assetToBaseCurrency;
    mapping(address => address) public assetToPricingModule;
    mapping(uint256 => BaseCurrencyInformation) public baseCurrencyToInformation;

    mapping(address => bool) public isActionAllowed;

    struct BaseCurrencyInformation {
        uint64 baseCurrencyToUsdOracleUnit;
        uint64 baseCurrencyUnitCorrection;
        address assetAddress;
        address baseCurrencyToUsdOracle;
        string baseCurrencyLabel;
    }

    /**
     * @dev Only Sub-registries can call functions marked by this modifier.
     *
     */
    modifier onlyPricingModule() {
        require(isPricingModule[msg.sender], "Caller is not a Price Module.");
        _;
    }

    modifier onlyVault() {
        require(IFactory(factoryAddress).isVault(msg.sender), "Caller is not a Vault.");
        _;
    }

    modifier noDelegate() {
        require(address(this) == _this, "Delegate calls not allowed.");
        _;
    }

    /**
     * @notice The Main Registry must always be initialised with the BaseCurrency USD
     * @dev Since the BaseCurrency USD has no native token, baseCurrencyDecimals should be set to 0 and assetAddress to the null address.
     * @param baseCurrencyInformation A Struct with information about the BaseCurrency USD
     * - baseCurrencyToUsdOracleUnit: Since there is no price oracle for usd to USD, this is 0 by default for USD
     * - baseCurrencyUnit: Since there is no native token for USD, this is 0 by default for USD
     * - assetAddress: Since there is no native token for usd, this is 0 address by default for USD
     * - baseCurrencyToUsdOracle: Since there is no price oracle for usd to USD, this is 0 address by default for USD
     * - baseCurrencyLabel: The symbol of the baseCurrency (only used for readability purpose)
     */
    constructor(BaseCurrencyInformation memory baseCurrencyInformation) {
        _this = address(this);
        //Main registry must be initialised with usd
        baseCurrencyToInformation[baseCurrencyCounter] = baseCurrencyInformation;
        assetToBaseCurrency[baseCurrencyInformation.assetAddress] = baseCurrencyCounter;
        baseCurrencies.push(baseCurrencyInformation.assetAddress);
        unchecked {
            ++baseCurrencyCounter;
        }
    }

    /* ///////////////////////////////////////////////////////////////
                        EXTERNAL CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets the Factory address
     * @param _factoryAddress The address of the Factory
     */
    function setFactory(address _factoryAddress) external onlyOwner {
        factoryAddress = _factoryAddress;
    }

    /**
     * @notice Sets an allowed action handler
     * @param action The address of the action handler
     * @param allowed Bool to indicate its status
     * @dev Can only be called by owner.
     */
    function setAllowedAction(address action, bool allowed) public onlyOwner {
        isActionAllowed[action] = allowed;
    }

    /* ///////////////////////////////////////////////////////////////
                        BASE CURRENCY MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Add a new baseCurrency (a unit in which price is measured, like USD or ETH) to the Main Registry, or overwrite an existing one
     * @param baseCurrencyInformation A Struct with information about the BaseCurrency
     * - baseCurrencyToUsdOracleUnit: The unit of the oracle, equal to 10 to the power of the number of decimals of the oracle
     * - baseCurrencyUnit: The unit of the baseCurrency, equal to 10 to the power of the number of decimals of the baseCurrency
     * - assetAddress: The contract address of the baseCurrency,
     * - baseCurrencyToUsdOracle: The contract address of the price oracle of the baseCurrency in USD
     * - baseCurrencyLabel: The symbol of the baseCurrency (only used for readability purpose)
     * @dev If the BaseCurrency has no native token, baseCurrencyDecimals should be set to 0 and assetAddress to the null address.
     * Tokens pegged to the native token do not count as native tokens
     * - USDC is not a native token for USD as BaseCurrency
     * - WETH is a native token for ETH as BaseCurrency
     * @dev The list of Risk Variables (Collateral Factor and Liquidation Threshold) should either be set through the pricing modules!
     * @dev Risk variable have 2 decimals precision
     */
    function addBaseCurrency(BaseCurrencyInformation calldata baseCurrencyInformation) external onlyOwner {
        baseCurrencyToInformation[baseCurrencyCounter] = baseCurrencyInformation;
        assetToBaseCurrency[baseCurrencyInformation.assetAddress] = baseCurrencyCounter;
        isBaseCurrency[baseCurrencyInformation.assetAddress] = true;
        baseCurrencies.push(baseCurrencyInformation.assetAddress);

        unchecked {
            ++baseCurrencyCounter;
        }
    }

    /* ///////////////////////////////////////////////////////////////
                        PRICE MODULE MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Add a Sub-registry Address to the list of Sub-Registries
     * @param subAssetRegistryAddress Address of the Sub-Registry
     */
    function addPricingModule(address subAssetRegistryAddress) external onlyOwner {
        require(!isPricingModule[subAssetRegistryAddress], "MR_APM: PriceMod. not unique");
        isPricingModule[subAssetRegistryAddress] = true;
        pricingModules.push(subAssetRegistryAddress);
    }

    /* ///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Disables the updatability of assets. In the disabled states, asset properties become immutable
     *
     */
    function setAssetsToNonUpdatable() external onlyOwner {
        assetsUpdatable = false;
    }

    /**
     * @notice Add a new asset to the Main Registry, or overwrite an existing one (if assetsUpdatable is True)
     * @param assetAddress The address of the asset
     * @dev The list of Risk Variables (Collateral Factor and Liquidation Threshold) should either be as long as
     * the number of assets added to the Main Registry,or the list must have length 0.
     * If the list has length zero, the risk variables of the baseCurrency for all assets
     * is initiated as default (safest lowest rating).
     * @dev Risk variable are variables with 2 decimals precision
     * @dev By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     * (for instance by changing the oracle address to a fake price feed) and poses a security risk towards protocol users.
     * This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     * assets are no longer updatable.
     */
    function addAsset(address assetAddress) external onlyPricingModule returns (bool) {
        if (inMainRegistry[assetAddress]) {
            require(assetsUpdatable, "MR_AA: Asset not updatable");
        } else {
            inMainRegistry[assetAddress] = true;
            assetsInMainRegistry.push(assetAddress);
        }
        assetToPricingModule[assetAddress] = msg.sender;

        return true;
    }

    /**
     * @notice Batch process multiple assets
     * @param assetAddresses An array of addresses of the assets
     * @param assetIds An array of asset ids
     * @param amounts An array of amounts to be deposited
     * @dev processDeposit in the pricing module checks whehter
     *    it's allowlisted and updates the maxExposure
     */
    function batchProcessDeposit(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) public onlyVault noDelegate {
        uint256 addressesLength = assetAddresses.length;
        require(addressesLength == assetIds.length && addressesLength == amounts.length, "MR_BPD: LENGTH_MISMATCH");

        address assetAddress;
        for (uint256 i; i < addressesLength;) {
            assetAddress = assetAddresses[i];

            require(inMainRegistry[assetAddress], "MR_BPD: Asset not in mainreg");
            IPricingModule(assetToPricingModule[assetAddress]).processDeposit(assetAddress, assetIds[i], amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Process a withdrawal for different assets
     * @param assetAddresses An array of addresses of the assets
     * @param amounts An array of amounts to be withdrawn
     * @dev batchProcessWithdrawal in the pricing module updates the maxExposure
     */
    function batchProcessWithdrawal(address[] calldata assetAddresses, uint256[] calldata amounts)
        public
        onlyVault
        noDelegate
    {
        uint256 addressesLength = assetAddresses.length;
        require(addressesLength == amounts.length, "MR_BPW: LENGTH_MISMATCH");

        address assetAddress;
        for (uint256 i; i < addressesLength;) {
            assetAddress = assetAddresses[i];

            IPricingModule(assetToPricingModule[assetAddress]).processWithdrawal(assetAddress, amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /* ///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Calculate the total value of a list of assets denominated in a given BaseCurrency
     * @param assetAddresses The List of token addresses of the assets
     * @param assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency The contract address of the BaseCurrency
     * @return valueInBaseCurrency The total value of the list of assets denominated in BaseCurrency
     */
    function getTotalValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) public view returns (uint256 valueInBaseCurrency) {
        valueInBaseCurrency = getTotalValue(assetAddresses, assetIds, assetAmounts, assetToBaseCurrency[baseCurrency]);
    }

    /**
     * @notice Calculate the total value of a list of assets denominated in a given BaseCurrency
     * @param assetAddresses The List of token addresses of the assets
     * @param assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency An identifier (uint256) of the BaseCurrency
     * @return valueInBaseCurrency The total value of the list of assets denominated in BaseCurrency
     * @dev ToDo: value sum unchecked. Cannot overflow on 1e18 decimals
     */
    function getTotalValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256 baseCurrency
    ) public view returns (uint256 valueInBaseCurrency) {
        uint256 valueInUsd;

        require(baseCurrency <= baseCurrencyCounter - 1, "MR_GTV: Unknown BaseCurrency");

        uint256 assetAddressesLength = assetAddresses.length;
        require(
            assetAddressesLength == assetIds.length && assetAddressesLength == assetAmounts.length,
            "MR_GTV: LENGTH_MISMATCH"
        );
        IPricingModule.GetValueInput memory getValueInput;
        getValueInput.baseCurrency = baseCurrency;

        address assetAddress;
        uint256 tempValueInUsd;
        uint256 tempValueInBaseCurrency;
        for (uint256 i; i < assetAddressesLength;) {
            assetAddress = assetAddresses[i];
            require(inMainRegistry[assetAddress], "MR_GTV: Unknown asset");

            getValueInput.assetAddress = assetAddress;
            getValueInput.assetId = assetIds[i];
            getValueInput.assetAmount = assetAmounts[i];

            if (assetAddress == baseCurrencyToInformation[baseCurrency].assetAddress) {
                //Should only be allowed if the baseCurrency is ETH, not for stablecoins or wrapped tokens
                valueInBaseCurrency = valueInBaseCurrency
                    + assetAmounts[i] * baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection; //assetAmounts can have a variable decimal precision -> bring to 18 decimals
            } else {
                //Calculate value of the next asset and add it to the total value of the vault, both tempValueInUsd and tempValueInBaseCurrency can be non-zero
                (tempValueInUsd, tempValueInBaseCurrency,,) =
                    IPricingModule(assetToPricingModule[assetAddress]).getValue(getValueInput);
                valueInUsd = valueInUsd + tempValueInUsd;
                valueInBaseCurrency = valueInBaseCurrency + tempValueInBaseCurrency;
            }
            unchecked {
                ++i;
            }
        }
        //Check if baseCurrency is USD
        if (baseCurrency == 0) {
            //Bring from internal 18 decimals to the number of decimals of baseCurrency
            return valueInUsd / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection;
        } else if (valueInUsd > 0) {
            //Get the BaseCurrency-USD rate
            (, int256 rate,,,) =
                IChainLinkData(baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracle).latestRoundData();
            //Add valueInUsd to valueInBaseCurrency
            valueInBaseCurrency = valueInBaseCurrency
                + valueInUsd.mulDivDown(baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracleUnit, uint256(rate));
        }
        //Bring from internal 18 decimals to the number of decimals of baseCurrency
        return valueInBaseCurrency / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection;
    }

    /**
     * @notice Calculate the value per asset of a list of assets denominated in a given BaseCurrency
     * @param assetAddresses The List of token addresses of the assets
     * @param assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency The contract address of the BaseCurrency
     * @return valuesAndRiskVarPerAsset The list of values per assets denominated in BaseCurrency
     */
    function getListOfValuesPerAsset(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) public view returns (RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset) {
        valuesAndRiskVarPerAsset =
            getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, assetToBaseCurrency[baseCurrency]);
    }

    /**
     * @notice Calculate the value per asset of a list of assets denominated in a given BaseCurrency
     * @param assetAddresses The List of token addresses of the assets
     * @param assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency An identifier (uint256) of the BaseCurrency
     * @return valuesAndRiskVarPerAsset The list of values per assets denominated in BaseCurrency
     */
    function getListOfValuesPerAsset(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256 baseCurrency
    ) public view returns (RiskModule.AssetValueAndRiskVariables[] memory) {
        require(baseCurrency <= baseCurrencyCounter - 1, "MR_GLV: Unknown BaseCurrency");

        uint256 assetAddressesLength = assetAddresses.length;
        require(
            assetAddressesLength == assetIds.length && assetAddressesLength == assetAmounts.length,
            "MR_GLV: LENGTH_MISMATCH"
        );
        IPricingModule.GetValueInput memory getValueInput;
        getValueInput.baseCurrency = baseCurrency;

        int256 rateBaseCurrencyToUsd;
        address assetAddress;
        uint256 tempValueInUsd;
        uint256 tempValueInBaseCurrency;
        RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset =
            new RiskModule.AssetValueAndRiskVariables[](assetAddressesLength);
        for (uint256 i; i < assetAddressesLength;) {
            assetAddress = assetAddresses[i];
            require(inMainRegistry[assetAddress], "MR_GLV: Unknown asset");

            getValueInput.assetAddress = assetAddress;
            getValueInput.assetId = assetIds[i];
            getValueInput.assetAmount = assetAmounts[i];

            if (assetAddress == baseCurrencyToInformation[baseCurrency].assetAddress) {
                //Should only be allowed if the baseCurrency is ETH, not for stablecoins or wrapped tokens
                valuesAndRiskVarPerAsset[i].valueInBaseCurrency = assetAmounts[i];
            } else {
                (
                    tempValueInUsd,
                    tempValueInBaseCurrency,
                    valuesAndRiskVarPerAsset[i].collFactor,
                    valuesAndRiskVarPerAsset[i].liqThreshold
                ) = IPricingModule(assetToPricingModule[assetAddress]).getValue(getValueInput);
                //Check if baseCurrency is USD
                if (baseCurrency == 0) {
                    //Bring from internal 18 decimals to the number of decimals of baseCurrency
                    valuesAndRiskVarPerAsset[i].valueInBaseCurrency =
                        tempValueInUsd / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection;
                } else if (tempValueInBaseCurrency > 0) {
                    //Bring from internal 18 decimals to the number of decimals of baseCurrency
                    valuesAndRiskVarPerAsset[i].valueInBaseCurrency =
                        tempValueInBaseCurrency / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection;
                } else {
                    //Check if the BaseCurrency-USD rate is already fetched
                    if (rateBaseCurrencyToUsd == 0) {
                        //Get the BaseCurrency-USD rate ToDo: Ask via the OracleHub?
                        (, rateBaseCurrencyToUsd,,,) = IChainLinkData(
                            baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracle
                        ).latestRoundData();
                    }
                    valuesAndRiskVarPerAsset[i].valueInBaseCurrency = tempValueInUsd.mulDivDown(
                        baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracleUnit,
                        uint256(rateBaseCurrencyToUsd)
                    ) / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection; //Bring from internal 18 decimals to the number of decimals of baseCurrency
                }
            }
            unchecked {
                ++i;
            }
        }
        return valuesAndRiskVarPerAsset;
    }

    /**
     * @notice Calculate the collateralValue given the asset details in given baseCurrency
     * @param assetAddresses The List of token addresses of the assets
     * @param assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency An address of the BaseCurrency contract
     * @return collateralValue Collateral value of the given assets denominated in BaseCurrency.
     */

    function getCollateralValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) public view returns (uint256 collateralValue) {
        //No need to heck that all arrays are of equal length, already done in getListOfValuesPerAsset()
        RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset =
            getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, baseCurrency);

        collateralValue = RiskModule.calculateWeightedCollateralValue(valuesAndRiskVarPerAsset);
    }

    /**
     * @notice Calculate the liquidation threshold given the asset details in given baseCurrency
     * @param assetAddresses The List of token addresses of the assets
     * @param assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency An (address) of the BaseCurrency contract
     * @return liquidationThreshold of the given assets
     */
    function getLiquidationThreshold(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) public view returns (uint256 liquidationThreshold) {
        //No need to heck that all arrays are of equal length, already done in getListOfValuesPerAsset()
        RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset =
            getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, baseCurrency);

        liquidationThreshold = RiskModule.calculateWeightedLiquidationThreshold(valuesAndRiskVarPerAsset);
    }

    /**
     * @notice Calculate the liquidation threshold given the asset details in given baseCurrency
     * @param assetAddresses The List of token addresses of the assets
     * @param assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency An (address) of the BaseCurrency contract
     * @return collateralValue Collateral value of the given assets denominated in BaseCurrency.
     * @return liquidationThreshold of the given assets
     */
    function getCollateralValueAndLiquidationThreshold(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) public view returns (uint256 collateralValue, uint256 liquidationThreshold) {
        //No need to check that all arrays are of equal length, already done in getListOfValuesPerAsset()
        RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset =
            getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, baseCurrency);

        (collateralValue, liquidationThreshold) =
            RiskModule.calculateCollateralValueAndLiquidationThreshold(valuesAndRiskVarPerAsset);
    }
}
