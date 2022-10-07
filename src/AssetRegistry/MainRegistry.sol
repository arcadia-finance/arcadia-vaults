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
import "../RiskModule.sol";

/**
 * @title Main Asset registry
 * @author Arcadia Finance
 * @notice The Main-registry stores basic information for each token that can, or could at some point, be deposited in the vaults
 * @dev No end-user should directly interact with the Main-registry, only vaults, Sub-Registries or the contract owner
 */
contract MainRegistry is Ownable, RiskModule {
    using FixedPointMathLib for uint256;

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

    /**
     * @notice The Main Registry must always be initialised with the BaseCurrency USD
     * @dev Since the BaseCurrency USD has no native token, baseCurrencyDecimals should be set to 0 and assetAddress to the null address.
     * @param _baseCurrencyInformation A Struct with information about the BaseCurrency USD
     * - baseCurrencyToUsdOracleUnit: Since there is no price oracle for usd to USD, this is 0 by default for USD
     * - baseCurrencyUnit: Since there is no native token for USD, this is 0 by default for USD
     * - assetAddress: Since there is no native token for usd, this is 0 address by default for USD
     * - baseCurrencyToUsdOracle: Since there is no price oracle for usd to USD, this is 0 address by default for USD
     * - baseCurrencyLabel: The symbol of the baseCurrency (only used for readability purpose)
     */
    constructor(BaseCurrencyInformation memory _baseCurrencyInformation) {
        //Main registry must be initialised with usd
        baseCurrencyToInformation[baseCurrencyCounter] = _baseCurrencyInformation;
        assetToBaseCurrency[_baseCurrencyInformation.assetAddress] = baseCurrencyCounter;
        baseCurrencies.push(_baseCurrencyInformation.assetAddress);
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
     * @param baseCurrencyCollateralFactors The List of collateral factors for the asset for the new base currency
     * @param baseCurrencyLiquidationThresholds The List of liquidation thresholds for each asset for the new base currency
     * @dev If the BaseCurrency has no native token, baseCurrencyDecimals should be set to 0 and assetAddress to the null address.
     * Tokens pegged to the native token do not count as native tokens
     * - USDC is not a native token for USD as BaseCurrency
     * - WETH is a native token for ETH as BaseCurrency
     * @dev The list of Risk Variables (Collateral Factor and Liquidation Threshold) should either be as long as
     * the number of assets added to the Main Registry,or the list must have length 0.
     * If the list has length zero, the risk variables of the baseCurrency for all assets
     * is initiated as default (safest lowest rating).
     * @dev Risk variable have 2 decimals precision
     */
    function addBaseCurrency(
        BaseCurrencyInformation calldata baseCurrencyInformation,
        uint16[] calldata baseCurrencyCollateralFactors,
        uint16[] calldata baseCurrencyLiquidationThresholds
    ) external onlyOwner {
        baseCurrencyToInformation[baseCurrencyCounter] = baseCurrencyInformation;
        assetToBaseCurrency[baseCurrencyInformation.assetAddress] = baseCurrencyCounter;
        isBaseCurrency[baseCurrencyInformation.assetAddress] = true;
        baseCurrencies.push(baseCurrencyInformation.assetAddress);

        // Check: Valid length of arrays
        uint256 baseCurrencyCollateralFactorsLength = baseCurrencyCollateralFactors.length;
        require(
            (
                baseCurrencyCollateralFactorsLength == assetsInMainRegistry.length
                    && baseCurrencyCollateralFactorsLength == baseCurrencyLiquidationThresholds.length
            ) || (baseCurrencyCollateralFactorsLength == 0 && baseCurrencyLiquidationThresholds.length == 0),
            "MR_ABC: LENGTH_MISMATCH"
        );
        // Logic Fork: If the list are empty, initate the variables with default collateralFactor and liquidationThreshold
        if (baseCurrencyCollateralFactorsLength == 0) {
            // Loop: Per base currency
            for (uint256 i; i < assetsInMainRegistry.length;) {
                // Write: Default variables for collateralFactor and liquidationThreshold
                collateralFactors[assetsInMainRegistry[i]][baseCurrencyCounter] = DEFAULT_COLLATERAL_FACTOR;
                liquidationThresholds[assetsInMainRegistry[i]][baseCurrencyCounter] = DEFAULT_LIQUIDATION_THRESHOLD;
                unchecked {
                    i++;
                }
            }
            unchecked {
                ++baseCurrencyCounter;
            }
            // Early termination
            return;
        }
        // Loop: Per value of collateral factor and liquidation threshold
        for (uint256 i; i < baseCurrencyCollateralFactorsLength;) {
            // Check: Values in the allowed limit
            require(
                baseCurrencyCollateralFactors[i] <= MAX_COLLATERAL_FACTOR
                    && baseCurrencyCollateralFactors[i] >= MIN_COLLATERAL_FACTOR,
                "MR_ABC: Coll.Fact not in limits"
            );
            require(
                baseCurrencyLiquidationThresholds[i] <= MAX_LIQUIDATION_THRESHOLD
                    && baseCurrencyLiquidationThresholds[i] >= MIN_LIQUIDATION_THRESHOLD,
                "MR_ABC: Liq.Thres not in limits"
            );

            collateralFactors[assetsInMainRegistry[i]][baseCurrencyCounter] = baseCurrencyCollateralFactors[i];
            liquidationThresholds[assetsInMainRegistry[i]][baseCurrencyCounter] = baseCurrencyLiquidationThresholds[i];

            unchecked {
                i++;
            }
        }

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
     * @param assetCollateralFactors The List of collateral factors for the asset for the different BaseCurrencies
     * @param assetLiquidationThresholds The List of liquidation thresholds for the asset for the different BaseCurrencies
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
    function addAsset(
        address assetAddress,
        uint16[] memory assetCollateralFactors,
        uint16[] memory assetLiquidationThresholds
    ) external onlyPricingModule {
        if (inMainRegistry[assetAddress]) {
            require(assetsUpdatable, "MR_AA: Asset not updatable");
        } else {
            inMainRegistry[assetAddress] = true;
            assetsInMainRegistry.push(assetAddress);
        }
        assetToPricingModule[assetAddress] = msg.sender;

        // Check: Valid length of arrays
        uint256 assetCollateralFactorsLength = assetCollateralFactors.length;
        require(
            (
                assetCollateralFactorsLength == baseCurrencyCounter
                    && assetCollateralFactorsLength == assetLiquidationThresholds.length
            ) || (assetCollateralFactorsLength == 0 && assetLiquidationThresholds.length == 0),
            "MR_AA: LENGTH_MISMATCH"
        );
        // Logic Fork: If the list are empty, initate the variables with default collateralFactor and liquidationThreshold
        if (assetCollateralFactorsLength == 0) {
            // Loop: Per base currency
            for (uint256 i; i < baseCurrencyCounter;) {
                // Write: Default variables for collateralFactor and liquidationThreshold
                collateralFactors[assetAddress][i] = DEFAULT_COLLATERAL_FACTOR;
                liquidationThresholds[assetAddress][i] = DEFAULT_LIQUIDATION_THRESHOLD;
                unchecked {
                    i++;
                }
            }
            // Early termination
            return;
        }
        // Loop: Per value of collateral factor and liquidation threshold
        for (uint256 i; i < assetCollateralFactorsLength;) {
            // Check: Values in the allowed limit
            require(
                assetCollateralFactors[i] <= MAX_COLLATERAL_FACTOR && assetCollateralFactors[i] >= MIN_COLLATERAL_FACTOR,
                "MR_AA: Coll.Fact not in limits"
            );
            require(
                assetLiquidationThresholds[i] <= MAX_LIQUIDATION_THRESHOLD
                    && assetLiquidationThresholds[i] >= MIN_LIQUIDATION_THRESHOLD,
                "MR_AA: Liq.Thres not in limits"
            );

            collateralFactors[assetAddress][i] = assetCollateralFactors[i];
            liquidationThresholds[assetAddress][i] = assetLiquidationThresholds[i];

            unchecked {
                i++;
            }
        }
    }

    /* ///////////////////////////////////////////////////////////////
                        WHITE LIST LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Checks for a list of tokens and a list of corresponding IDs if all tokens are white-listed
     * @param _assetAddresses The list of token addresses that needs to be checked
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @return A boolean, indicating of all assets passed as input are whitelisted
     */
    function batchIsWhiteListed(address[] calldata _assetAddresses, uint256[] calldata _assetIds)
        public
        view
        returns (bool)
    {
        uint256 addressesLength = _assetAddresses.length;
        require(addressesLength == _assetIds.length, "LENGTH_MISMATCH");

        address assetAddress;
        for (uint256 i; i < addressesLength;) {
            assetAddress = _assetAddresses[i];
            if (!inMainRegistry[assetAddress]) {
                return false;
            } else if (!IPricingModule(assetToPricingModule[assetAddress]).isWhiteListed(assetAddress, _assetIds[i])) {
                return false;
            }
            unchecked {
                ++i;
            }
        }

        return true;
    }

    /**
     * @notice returns a list of all white-listed token addresses
     * @dev Function is not gas-optimsed and not intended to be called by other smart contracts
     * @return whiteList A list of all white listed token Adresses
     */
    function getWhiteList() external view returns (address[] memory whiteList) {
        uint256 maxLength = assetsInMainRegistry.length;
        whiteList = new address[](maxLength);

        uint256 counter = 0;
        for (uint256 i; i < maxLength;) {
            address assetAddress = assetsInMainRegistry[i];
            if (IPricingModule(assetToPricingModule[assetAddress]).isAssetAddressWhiteListed(assetAddress)) {
                whiteList[counter] = assetAddress;
                unchecked {
                    ++counter;
                }
            }
            unchecked {
                ++i;
            }
        }

        return whiteList;
    }

    /* ///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Change the Risk Variables for one or more assets for one or more baseCurrencies
     * @param assets The List of addresses of the assets
     * @param _baseCurrencies The corresponding List of BaseCurrencies
     * @param newCollateralFactors The corresponding List of new Collateral Factors
     * @param newLiquidationThresholds The corresponding List of new Liquidation Thresholds
     * @dev The function loops over all indexes, and changes for each index the Risk Variable of the combination of asset and baseCurrency.
     * In case multiple Risk Variables for the same assets need to be changed, the address must be repeated in the assets.
     * @dev Risk variable have 2 decimals precision.
     */
    function batchSetRiskVariables(
        address[] calldata assets,
        uint256[] calldata _baseCurrencies,
        uint16[] calldata newCollateralFactors,
        uint16[] calldata newLiquidationThresholds
    ) external onlyOwner {
        uint256 assetsLength = assets.length;
        require(
            assetsLength == _baseCurrencies.length && assetsLength == newCollateralFactors.length
                && assetsLength == newLiquidationThresholds.length,
            "MR_BSCR: LENGTH_MISMATCH"
        );

        for (uint256 i; i < assetsLength;) {
            // Check: Values in the allowed limit
            require(
                newCollateralFactors[i] <= MAX_COLLATERAL_FACTOR && newCollateralFactors[i] >= MIN_COLLATERAL_FACTOR,
                "MR_BSRV: CollFact not in limits"
            );
            require(
                newLiquidationThresholds[i] < MAX_LIQUIDATION_THRESHOLD
                    && newLiquidationThresholds[i] >= MIN_LIQUIDATION_THRESHOLD,
                "MR_BSRV: Liq.Thres not in limits"
            );
            collateralFactors[assets[i]][_baseCurrencies[i]] = newCollateralFactors[i];
            liquidationThresholds[assets[i]][_baseCurrencies[i]] = newLiquidationThresholds[i];
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
     * @param _assetAddresses The List of token addresses of the assets
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param _assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency The contract address of the BaseCurrency
     * @return valueInBaseCurrency The total value of the list of assets denominated in BaseCurrency
     */
    function getTotalValue(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        address baseCurrency
    ) public view returns (uint256 valueInBaseCurrency) {
        valueInBaseCurrency =
            getTotalValue(_assetAddresses, _assetIds, _assetAmounts, assetToBaseCurrency[baseCurrency]);
    }

    /**
     * @notice Calculate the total value of a list of assets denominated in a given BaseCurrency
     * @param _assetAddresses The List of token addresses of the assets
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param _assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency An identifier (uint256) of the BaseCurrency
     * @return valueInBaseCurrency The total value of the list of assets denominated in BaseCurrency
     * @dev ToDo: value sum unchecked. Cannot overflow on 1e18 decimals
     */
    function getTotalValue(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        uint256 baseCurrency
    ) public view returns (uint256 valueInBaseCurrency) {
        uint256 valueInUsd;

        require(baseCurrency <= baseCurrencyCounter - 1, "MR_GTV: Unknown BaseCurrency");

        uint256 assetAddressesLength = _assetAddresses.length;
        require(
            assetAddressesLength == _assetIds.length && assetAddressesLength == _assetAmounts.length,
            "MR_GTV: LENGTH_MISMATCH"
        );
        IPricingModule.GetValueInput memory getValueInput;
        getValueInput.baseCurrency = baseCurrency;

        address assetAddress;
        uint256 tempValueInUsd;
        uint256 tempValueInBaseCurrency;
        for (uint256 i; i < assetAddressesLength;) {
            assetAddress = _assetAddresses[i];
            require(inMainRegistry[assetAddress], "MR_GTV: Unknown asset");

            getValueInput.assetAddress = assetAddress;
            getValueInput.assetId = _assetIds[i];
            getValueInput.assetAmount = _assetAmounts[i];

            if (assetAddress == baseCurrencyToInformation[baseCurrency].assetAddress) {
                //Should only be allowed if the baseCurrency is ETH, not for stablecoins or wrapped tokens
                valueInBaseCurrency = valueInBaseCurrency
                    + _assetAmounts[i] * baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection; //_assetAmounts can have a variable decimal precision -> bring to 18 decimals
            } else {
                //Calculate value of the next asset and add it to the total value of the vault, both tempValueInUsd and tempValueInBaseCurrency can be non-zero
                (tempValueInUsd, tempValueInBaseCurrency) =
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
     * @param _assetAddresses The List of token addresses of the assets
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param _assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency The contract address of the BaseCurrency
     * @return valuesPerAsset The list of values per assets denominated in BaseCurrency
     */
    function getListOfValuesPerAsset(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        address baseCurrency
    ) public view returns (uint256[] memory valuesPerAsset) {
        valuesPerAsset =
            getListOfValuesPerAsset(_assetAddresses, _assetIds, _assetAmounts, assetToBaseCurrency[baseCurrency]);
    }

    /**
     * @notice Calculate the value per asset of a list of assets denominated in a given BaseCurrency
     * @param _assetAddresses The List of token addresses of the assets
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param _assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency An identifier (uint256) of the BaseCurrency
     * @return valuesPerAsset The list of values per assets denominated in BaseCurrency
     */
    function getListOfValuesPerAsset(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        uint256 baseCurrency
    ) public view returns (uint256[] memory valuesPerAsset) {
        valuesPerAsset = new uint256[](_assetAddresses.length);

        require(baseCurrency <= baseCurrencyCounter - 1, "MR_GLV: Unknown BaseCurrency");

        uint256 assetAddressesLength = _assetAddresses.length;
        require(
            assetAddressesLength == _assetIds.length && assetAddressesLength == _assetAmounts.length,
            "MR_GLV: LENGTH_MISMATCH"
        );
        IPricingModule.GetValueInput memory getValueInput;
        getValueInput.baseCurrency = baseCurrency;

        int256 rateBaseCurrencyToUsd;
        address assetAddress;
        uint256 valueInUsd;
        uint256 valueInBaseCurrency;
        for (uint256 i; i < assetAddressesLength;) {
            assetAddress = _assetAddresses[i];
            require(inMainRegistry[assetAddress], "MR_GLV: Unknown asset");

            getValueInput.assetAddress = assetAddress;
            getValueInput.assetId = _assetIds[i];
            getValueInput.assetAmount = _assetAmounts[i];

            if (assetAddress == baseCurrencyToInformation[baseCurrency].assetAddress) {
                //Should only be allowed if the baseCurrency is ETH, not for stablecoins or wrapped tokens
                valuesPerAsset[i] = _assetAmounts[i];
            } else {
                (valueInUsd, valueInBaseCurrency) =
                    IPricingModule(assetToPricingModule[assetAddress]).getValue(getValueInput);
                //Check if baseCurrency is USD
                if (baseCurrency == 0) {
                    //Bring from internal 18 decimals to the number of decimals of baseCurrency
                    valuesPerAsset[i] = valueInUsd / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection;
                } else if (valueInBaseCurrency > 0) {
                    //Bring from internal 18 decimals to the number of decimals of baseCurrency
                    valuesPerAsset[i] =
                        valueInBaseCurrency / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection;
                } else {
                    //Check if the BaseCurrency-USD rate is already fetched
                    if (rateBaseCurrencyToUsd == 0) {
                        //Get the BaseCurrency-USD rate ToDo: Ask via the OracleHub?
                        (, rateBaseCurrencyToUsd,,,) = IChainLinkData(
                            baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracle
                        ).latestRoundData();
                    }
                    valuesPerAsset[i] = valueInUsd.mulDivDown(
                        baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracleUnit,
                        uint256(rateBaseCurrencyToUsd)
                    ) / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection; //Bring from internal 18 decimals to the number of decimals of baseCurrency
                }
            }
            unchecked {
                ++i;
            }
        }
        return valuesPerAsset;
    }

    /**
     * @notice Calculate the collateralValue given the asset details in given baseCurrency
     * @param _assetAddresses The List of token addresses of the assets
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param _assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency An address of the BaseCurrency contract
     * @return collateralValue Collateral value of the given assets denominated in BaseCurrency.
     */

    function getCollateralValue(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        address baseCurrency
    ) public view returns (uint256 collateralValue) {
        uint256 assetAddressesLength = _assetAddresses.length;

        require(
            assetAddressesLength == _assetIds.length && assetAddressesLength == _assetAmounts.length,
            "MR_GCV: LENGTH_MISMATCH"
        );
        uint256 baseCurrencyInd = assetToBaseCurrency[baseCurrency];
        uint256[] memory valuesPerAsset =
            getListOfValuesPerAsset(_assetAddresses, _assetIds, _assetAmounts, baseCurrencyInd);
        collateralValue = calculateWeightedCollateralValue(_assetAddresses, valuesPerAsset, baseCurrencyInd);
    }

    /**
     * @notice Calculate the liquidation threshold given the asset details in given baseCurrency
     * @param _assetAddresses The List of token addresses of the assets
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param _assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency An (address) of the BaseCurrency contract
     * @return liquidationThreshold of the given assets
     */
    function getLiquidationThreshold(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        address baseCurrency
    ) public view returns (uint256 liquidationThreshold) {
        require(
            _assetAddresses.length == _assetIds.length && _assetAddresses.length == _assetAmounts.length,
            "MR_GCF: LENGTH_MISMATCH"
        );
        uint256 baseCurrencyInd = assetToBaseCurrency[baseCurrency];
        uint256[] memory valuesPerAsset =
            getListOfValuesPerAsset(_assetAddresses, _assetIds, _assetAmounts, baseCurrencyInd);
        liquidationThreshold = calculateWeightedLiquidationThreshold(_assetAddresses, valuesPerAsset, baseCurrencyInd);
    }
}
