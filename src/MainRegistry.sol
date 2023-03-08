/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { IChainLinkData } from "./interfaces/IChainLinkData.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { IPricingModule } from "./interfaces/IPricingModule.sol";
import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { RiskModule } from "./RiskModule.sol";
import { MainRegistryGuardian } from "./security/MainRegistryGuardian.sol";

/**
 * @title Main Asset registry
 * @author Pragma Labs
 * @notice The Main Registry stores basic information for each token that can, or could at some point, be deposited in the Vaults.
 * @dev No end-user should directly interact with the Main Registry, only vaults, Pricing Modules or the contract owner.
 */
contract MainRegistry is IMainRegistry, MainRegistryGuardian {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The contract address of the this contract,
    // used to prevent delegateCalls for certain functions.
    address immutable _this;
    // Counter for the number of baseCurrencies in use.
    uint256 public baseCurrencyCounter;
    // Contract address of the Factory.
    address public immutable factory;

    // Array with all the contract addresses of Pricing Modules.
    address[] public pricingModules;
    // Array with all the contract addresses of Tokens that can be Priced.
    address[] public assetsInMainRegistry;
    // Array with all the contract addresses of baseCurrencies.
    address[] public baseCurrencies;

    // Map mainRegistry => flag.
    mapping(address => bool) public inMainRegistry;
    // Map pricingModule => flag.
    mapping(address => bool) public isPricingModule;
    // Map baseCurrency => flag.
    mapping(address => bool) public isBaseCurrency;
    // Map action => flag.
    mapping(address => bool) public isActionAllowed;
    // Map baseCurrency => baseCurrencyIdentifier.
    mapping(address => uint256) public assetToBaseCurrency;
    // Map asset => assetInformation.
    mapping(address => AssetInformation) public assetToAssetInformation;
    // Map baseCurrencyIdentifier => baseCurrencyInformation.
    mapping(uint256 => BaseCurrencyInformation) public baseCurrencyToInformation;

    // Struct with additional information for a specific asset.
    struct AssetInformation {
        uint96 assetType; // Identifier for the token standard of the asset.
        address pricingModule; // Contract address of the module that can price the specific asset.
    }

    // Struct with additional information for a specific baseCurrency.
    struct BaseCurrencyInformation {
        uint64 baseCurrencyUnitCorrection; // The factor with which the baseCurrency should be multiplied to bring it to 18 decimals.
        address assetAddress; // The contract address of the baseCurrency.
        uint64 baseCurrencyToUsdOracleUnit; // The unit of the oracle, equal to 10^decimalsOracle.
        address baseCurrencyToUsdOracle; // The contract address of the pricing oracle for baseCurrency -> USD.
        bytes8 baseCurrencyLabel; // Human readable label.
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event BaseCurrencyAdded(address indexed assetAddress, uint8 indexed baseCurrencyId, bytes8 label);
    event AllowedActionSet(address indexed action, bool allowed);
    event PricingModuleAdded(address pricingModule);
    event AssetAdded(address indexed assetAddress, address indexed pricingModule, uint8 assetType);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Only Pricing Modules can call functions with this modifier.
     */
    modifier onlyPricingModule() {
        require(isPricingModule[msg.sender], "MR: Only PriceMod.");
        _;
    }

    /**
     * @dev Only Vaults can call functions with this modifier.
     * @dev Cannot be called via delegate calls.
     */
    modifier onlyVault() {
        require(IFactory(factory).isVault(msg.sender), "MR: Only Vaults.");
        require(address(this) == _this, "MR: No delegate.");
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param factory_ The contract address of the Factory.
     * @dev The mainRegistry must be initialised with baseCurrency USD, at baseCurrencyCounter of 0.
     * Usd is initialised with the following BaseCurrencyInformation.
     * - baseCurrencyToUsdOracleUnit: Since there is no price oracle for usd to USD, this is 0 by default for USD.
     * - baseCurrencyUnitCorrection: We use 18 decimals precision for USD, so unitCorrection is 1 for USD.
     * - assetAddress: Since there is no native token for usd, this is the 0 address by default for USD.
     * - baseCurrencyToUsdOracle: Since there is no price oracle for usd to USD, this is the 0 address by default for USD.
     * - baseCurrencyLabel: 'USD' (only used for readability purpose).
     */
    constructor(address factory_) {
        _this = address(this);
        factory = factory_;

        //Main Registry must be initialised with usd, other values of baseCurrencyToInformation[0] are 0 or the zero-address.
        baseCurrencyToInformation[0].baseCurrencyLabel = "USD";
        baseCurrencyToInformation[0].baseCurrencyUnitCorrection = 1;

        //Usd is the first baseCurrency at index 0 of array baseCurrencies.
        isBaseCurrency[address(0)] = true;
        baseCurrencies.push(address(0));
        baseCurrencyCounter = 1;

        emit BaseCurrencyAdded(address(0), 0, "USD");
    }

    /* ///////////////////////////////////////////////////////////////
                        EXTERNAL CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets an allowed action handler.
     * @param action The address of the action handler.
     * @param allowed Bool to indicate its status.
     * @dev Can only be called by owner.
     */
    function setAllowedAction(address action, bool allowed) external onlyOwner {
        isActionAllowed[action] = allowed;

        emit AllowedActionSet(action, allowed);
    }

    /* ///////////////////////////////////////////////////////////////
                        BASE CURRENCY MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds a new baseCurrency (a unit of account in which price is denominated, like USD or ETH) to the Main Registry.
     * @param baseCurrencyInformation A Struct with information about the BaseCurrency:
     * - baseCurrencyToUsdOracleUnit: The unit of the oracle, equal to 10^decimalsOracle.
     * - baseCurrencyUnitCorrection: The factor with which the baseCurrency should be multiplied to bring it to 18 decimals.
     * - assetAddress: The contract address of the baseCurrency.
     * - baseCurrencyToUsdOracle: The contract address of the pricing oracle for baseCurrency -> USD.
     * - baseCurrencyLabel: Human readable label.
     * @dev If the BaseCurrency has no native token (USD, EUR...), baseCurrencyDecimals is 0 and assetAddress the null address.
     * Tokens pegged to the native token do not count as native tokens.
     * - USDC is not a native token for USD as BaseCurrency.
     * - WETH is a native token for ETH as BaseCurrency.
     * @dev A baseCurrency cannot be added twice, as that would result in the ability to manipulate prices.
     */
    function addBaseCurrency(BaseCurrencyInformation calldata baseCurrencyInformation) external onlyOwner {
        require(!isBaseCurrency[baseCurrencyInformation.assetAddress], "MR_ABC: BaseCurrency exists");

        baseCurrencyToInformation[baseCurrencyCounter] = baseCurrencyInformation;
        assetToBaseCurrency[baseCurrencyInformation.assetAddress] = baseCurrencyCounter;
        isBaseCurrency[baseCurrencyInformation.assetAddress] = true;
        baseCurrencies.push(baseCurrencyInformation.assetAddress);

        unchecked {
            ++baseCurrencyCounter;
        }

        emit BaseCurrencyAdded(
            baseCurrencyInformation.assetAddress, uint8(baseCurrencyCounter), baseCurrencyInformation.baseCurrencyLabel
        );
    }

    /**
     * @notice Sets a new oracle for the rate baseCurrency-USD.
     * @param baseCurrency The identifier of the baseCurrency for which the new oracle is set.
     * @param newOracle The new oracle address.
     * @param baseCurrencyToUsdOracleUnit The new baseCurrencyToUsdOracleUnit.
     * @dev This function is part of an oracle failsafe mechanism.
     * New oracles can only be set if the current oracle is not performing as intended:
     * - A call to the oracle reverts.
     * - The oracle returns the minimum value.
     * - The oracle returns the maximum value.
     * - The oracle didn't update for over a week.
     * @dev This function could be called to set a new oracle address for the baseCurrency USD (since it is initiated with the zero address).
     * This oracle is however never used, hence would not cause any problems (except gas waste).
     */
    function setOracle(uint256 baseCurrency, address newOracle, uint64 baseCurrencyToUsdOracleUnit)
        external
        onlyOwner
    {
        require(baseCurrency < baseCurrencyCounter, "MR_SO: UNKNOWN_BASECURRENCY");

        bool oracleIsHealthy = true;
        address oldOracle = baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracle;

        try IChainLinkData(oldOracle).latestRoundData() returns (
            uint80, int256 answer, uint256, uint256 updatedAt, uint80
        ) {
            if (answer <= IChainLinkData(IChainLinkData(oldOracle).aggregator()).minAnswer()) {
                oracleIsHealthy = false;
            } else if (answer >= IChainLinkData(IChainLinkData(oldOracle).aggregator()).maxAnswer()) {
                oracleIsHealthy = false;
            } else if (updatedAt <= block.timestamp - 1 weeks) {
                oracleIsHealthy = false;
            }
        } catch {
            oracleIsHealthy = false;
        }

        if (oracleIsHealthy) {
            revert("MR_SO: ORACLE_HEALTHY");
        } else {
            baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracle = newOracle;
            baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracleUnit = baseCurrencyToUsdOracleUnit;
        }
    }

    /* ///////////////////////////////////////////////////////////////
                        PRICE MODULE MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds a new Pricing Module to the Main Registry.
     * @param pricingModule The contract address of the Pricing Module.
     */
    function addPricingModule(address pricingModule) external onlyOwner {
        require(!isPricingModule[pricingModule], "MR_APM: PriceMod. not unique");
        isPricingModule[pricingModule] = true;
        pricingModules.push(pricingModule);

        emit PricingModuleAdded(pricingModule);
    }

    /* ///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds a new asset to the Main Registry.
     * @param assetAddress The contract address of the asset.
     * @param assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * @dev Assets that are already in the mainRegistry cannot be overwritten,
     * as that would make it possible for devs to change the asset pricing.
     */
    function addAsset(address assetAddress, uint256 assetType) external onlyPricingModule {
        require(!inMainRegistry[assetAddress], "MR_AA: Asset already in mainreg");
        require(assetType <= type(uint96).max, "MR_AA: Invalid AssetType");

        inMainRegistry[assetAddress] = true;
        assetsInMainRegistry.push(assetAddress);
        assetToAssetInformation[assetAddress] =
            AssetInformation({ assetType: uint96(assetType), pricingModule: msg.sender });

        emit AssetAdded(assetAddress, msg.sender, uint8(assetType));
    }

    /**
     * @notice Batch deposit multiple assets.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param amounts Array with the amounts of the assets.
     * @return assetTypes Array with the types of the assets.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     * @dev processDeposit in the pricing module checks whether it's allowlisted and updates the exposure.
     */
    function batchProcessDeposit(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external whenDepositNotPaused onlyVault returns (uint256[] memory assetTypes) {
        uint256 addressesLength = assetAddresses.length;
        require(addressesLength == assetIds.length && addressesLength == amounts.length, "MR_BPD: LENGTH_MISMATCH");

        address assetAddress;
        assetTypes = new uint256[](addressesLength);
        for (uint256 i; i < addressesLength;) {
            assetAddress = assetAddresses[i];
            assetTypes[i] = assetToAssetInformation[assetAddress].assetType;

            IPricingModule(assetToAssetInformation[assetAddress].pricingModule).processDeposit(
                msg.sender, assetAddress, assetIds[i], amounts[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Batch withdraw multiple assets.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param amounts Array with the amounts of the assets.
     * @return assetTypes Array with the types of the assets.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     * @dev batchProcessWithdrawal in the pricing module updates the exposure.
     */
    function batchProcessWithdrawal(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external whenWithdrawNotPaused onlyVault returns (uint256[] memory assetTypes) {
        uint256 addressesLength = assetAddresses.length;
        require(addressesLength == assetIds.length && addressesLength == amounts.length, "MR_BPW: LENGTH_MISMATCH");

        address assetAddress;
        assetTypes = new uint256[](addressesLength);
        for (uint256 i; i < addressesLength;) {
            assetAddress = assetAddresses[i];
            assetTypes[i] = assetToAssetInformation[assetAddress].assetType;

            IPricingModule(assetToAssetInformation[assetAddress].pricingModule).processWithdrawal(
                msg.sender, assetAddress, assetIds[i], amounts[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /* ///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Calculates the value per asset, denominated in a given BaseCurrency.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param baseCurrency An identifier (uint256) of the BaseCurrency.
     * @return valuesAndRiskVarPerAsset The array of values per assets, denominated in BaseCurrency.
     * @dev For each token address, a corresponding id and amount at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0.
     * @dev No checks of input parameters necessary, all generated by the Vault.
     * Additionally, unknown assetAddresses cause IPricingModule(assetAddresses) to revert,
     * Unknown baseCurrency will cause IChainLinkData(baseCurrency) to revert.
     * Non-equal lists will or revert, or not take all assets into account -> lower value as actual.
     */
    function getListOfValuesPerAsset(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256 baseCurrency
    ) public view returns (RiskModule.AssetValueAndRiskVariables[] memory) {
        // Cache Output array.
        uint256 assetAddressesLength = assetAddresses.length;
        RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset =
            new RiskModule.AssetValueAndRiskVariables[](assetAddressesLength);

        // Cache variables.
        IPricingModule.GetValueInput memory getValueInput;
        getValueInput.baseCurrency = baseCurrency;
        int256 rateBaseCurrencyToUsd;
        address assetAddress;
        uint256 valueInUsd;
        uint256 valueInBaseCurrency;

        // Get the BaseCurrency-USD rate if the BaseCurrency is different from USD.
        if (baseCurrency > 0) {
            (, rateBaseCurrencyToUsd,,,) =
                IChainLinkData(baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracle).latestRoundData();
        }

        // Loop over all assets.
        for (uint256 i; i < assetAddressesLength;) {
            assetAddress = assetAddresses[i];

            // If the asset is identical to the base Currency, we do not need to get a rate.
            // We only need to fetch the risk variables from the PricingModule.
            if (assetAddress == baseCurrencyToInformation[baseCurrency].assetAddress) {
                valuesAndRiskVarPerAsset[i].valueInBaseCurrency = assetAmounts[i];
                (valuesAndRiskVarPerAsset[i].collateralFactor, valuesAndRiskVarPerAsset[i].liquidationFactor) =
                IPricingModule(assetToAssetInformation[assetAddress].pricingModule).getRiskVariables(
                    assetAddress, baseCurrency
                );

                // Else we need to fetch the value in the assets' PricingModule.
            } else {
                // Prepare input.
                getValueInput.asset = assetAddress;
                getValueInput.assetId = assetIds[i];
                getValueInput.assetAmount = assetAmounts[i];

                // Fetch the Value and the risk variables in the PricingModule.
                (
                    valueInUsd,
                    valueInBaseCurrency,
                    valuesAndRiskVarPerAsset[i].collateralFactor,
                    valuesAndRiskVarPerAsset[i].liquidationFactor
                ) = IPricingModule(assetToAssetInformation[assetAddress].pricingModule).getValue(getValueInput);

                // If the baseCurrency is USD (identifier 0), IPricingModule().getValue will always return the value in USD (valueInBaseCurrency = 0).
                if (baseCurrency == 0) {
                    //USD has hardcoded precision of 18 decimals (baseCurrencyUnitCorrection set to 1).
                    //Since internal precision of value calculations is also 18 decimals, no need for a unit correction.
                    valuesAndRiskVarPerAsset[i].valueInBaseCurrency = valueInUsd;
                } else {
                    //If the baseCurrency is different from USD, both valueInUsd and valueInBaseCurrency can be non-zero.
                    //Calculate the equivalent of valueInUsd denominated in BaseCurrency and add it to valueInBaseCurrency.
                    //And bring the final valueInBaseCurrency from internal 18 decimals to the actual number of decimals of baseCurrency.
                    unchecked {
                        valuesAndRiskVarPerAsset[i].valueInBaseCurrency = (
                            valueInUsd.mulDivDown(
                                baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracleUnit,
                                uint256(rateBaseCurrencyToUsd)
                            ) + valueInBaseCurrency
                        ) / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection;
                    }
                }
            }
            unchecked {
                ++i;
            }
        }
        return valuesAndRiskVarPerAsset;
    }

    /**
     * @notice Calculates the values per asset, denominated in a given BaseCurrency.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @return valuesAndRiskVarPerAsset The array of values per assets, denominated in BaseCurrency.
     * @dev No need to check equality of length of arrays, since they are generated by the Vault.
     */
    function getListOfValuesPerAsset(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) external view returns (RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset) {
        require(isBaseCurrency[baseCurrency], "MR_GLVA: UNKNOWN_BASECURRENCY");
        valuesAndRiskVarPerAsset =
            getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, assetToBaseCurrency[baseCurrency]);
    }

    /**
     * @notice Calculates the combined value of a combination of assets, denominated in a given BaseCurrency.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @return valueInBaseCurrency The combined value of the assets, denominated in BaseCurrency.
     * @dev No need to check equality of length of arrays, since they are generated by the Vault.
     */
    function getTotalValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) public view returns (uint256 valueInBaseCurrency) {
        require(isBaseCurrency[baseCurrency], "MR_GTV: UNKNOWN_BASECURRENCY");

        RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset =
            getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, assetToBaseCurrency[baseCurrency]);

        for (uint256 i = 0; i < valuesAndRiskVarPerAsset.length;) {
            valueInBaseCurrency += valuesAndRiskVarPerAsset[i].valueInBaseCurrency;
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculates the collateralValue of a combination of assets, denominated in a given BaseCurrency.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @return collateralValue The collateral value of the assets, denominated in BaseCurrency.
     * @dev No need to check equality of length of arrays, since they are generated by the Vault.
     * @dev The collateral value is equal to the spot value of the assets,
     * discounted by a haircut (the collateral factor).
     */
    function getCollateralValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) external view returns (uint256 collateralValue) {
        require(isBaseCurrency[baseCurrency], "MR_GCV: UNKNOWN_BASECURRENCY");

        RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset =
            getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, assetToBaseCurrency[baseCurrency]);

        collateralValue = RiskModule.calculateCollateralValue(valuesAndRiskVarPerAsset);
    }

    /**
     * @notice Calculates the getLiquidationValue of a combination of assets, denominated in a given BaseCurrency.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @return liquidationValue The liquidation value of the assets, denominated in BaseCurrency.
     * @dev No need to check equality of length of arrays, since they are generated by the Vault.
     * @dev The liquidation value is equal to the spot value of the assets,
     * discounted by a haircut (the liquidation factor).
     */
    function getLiquidationValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) external view returns (uint256 liquidationValue) {
        require(isBaseCurrency[baseCurrency], "MR_GLV: UNKNOWN_BASECURRENCY");

        RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset =
            getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, assetToBaseCurrency[baseCurrency]);

        liquidationValue = RiskModule.calculateLiquidationValue(valuesAndRiskVarPerAsset);
    }
}
