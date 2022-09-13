/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../interfaces/IChainLinkData.sol";
import "../interfaces/IOraclesHub.sol";
import "../interfaces/IFactory.sol";
import "../interfaces/ISubRegistry.sol";

import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

/**
 * @title Main Asset registry
 * @author Arcadia Finance
 * @notice The Main-registry stores basic information for each token that can, or could at some point, be deposited in the vaults
 * @dev No end-user should directly interact with the Main-registry, only vaults, Sub-Registries or the contract owner
 */
contract MainRegistry is Ownable {
    using FixedPointMathLib for uint256;

    bool public assetsUpdatable = true;

    uint256 public constant CREDIT_RATING_CATOGERIES = 10;
    uint256 public baseCurrencyCounter;

    address public factoryAddress;
    address[] private subRegistries;
    address[] public assetsInMainRegistry;
    address[] public baseCurrencies;

    mapping(address => bool) public inMainRegistry;
    mapping(address => bool) public isSubRegistry;
    mapping(address => address) public assetToSubRegistry;
    mapping(uint256 => BaseCurrencyInformation) public baseCurrencyToInformation;
    mapping(address => mapping(uint256 => uint256))
        public assetToBaseCurrencyToCreditRating;
    mapping(address => uint256) public assetToBaseCurrency;
    mapping(address => bool) public isBaseCurrency;

    struct BaseCurrencyInformation {
        uint64 baseCurrencyToUsdOracleUnit;
        uint64 baseCurrencyUnitCorrection;
        address assetAddress;
        address baseCurrencyToUsdOracle;
        string baseCurrencyLabel;
    }

    /**
     * @dev Only Sub-registries can call functions marked by this modifier.
     **/
    modifier onlySubRegistry() {
        require(isSubRegistry[msg.sender], "Caller is not a sub-registry.");
        _;
    }

    /**
     * @notice The Main Registry must always be initialised with the BaseCurrency USD
     * @dev Since the BaseCurrency USD has no native token, baseCurrencyDecimals should be set to 0 and assetAddress to the null address.
     * @param _baseCurrencyInformation A Struct with information about the BaseCurrency USD
     *                              - baseCurrencyToUsdOracleUnit: Since there is no price oracle for usd to USD, this is 0 by default for USD
     *                              - baseCurrencyUnit: Since there is no native token for USD, this is 0 by default for USD
     *                              - assetAddress: Since there is no native token for usd, this is 0 address by default for USD
     *                              - baseCurrencyToUsdOracle: Since there is no price oracle for usd to USD, this is 0 address by default for USD
     *                              - baseCurrencyLabel: The symbol of the baseCurrency (only used for readability purpose)
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

    /**
     * @notice Sets the Factory address
     * @param _factoryAddress The address of the Factory
     */
    function setFactory(address _factoryAddress) external onlyOwner {
        factoryAddress = _factoryAddress;
    }

    /**
     * @notice Checks for a list of tokens and a list of corresponding IDs if all tokens are white-listed
     * @param _assetAddresses The list of token addresses that needs to be checked
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     *      for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @return A boolean, indicating of all assets passed as input are whitelisted
     */
    function batchIsWhiteListed(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds
    ) public view returns (bool) {
        uint256 addressesLength = _assetAddresses.length;
        require(addressesLength == _assetIds.length, "LENGTH_MISMATCH");

        address assetAddress;
        for (uint256 i; i < addressesLength; ) {
            assetAddress = _assetAddresses[i];
            if (!inMainRegistry[assetAddress]) {
                return false;
            } else if (
                !ISubRegistry(assetToSubRegistry[assetAddress]).isWhiteListed(
                    assetAddress,
                    _assetIds[i]
                )
            ) {
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
        for (uint256 i; i < maxLength; ) {
            address assetAddress = assetsInMainRegistry[i];
            if (
                ISubRegistry(assetToSubRegistry[assetAddress])
                    .isAssetAddressWhiteListed(assetAddress)
            ) {
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

    /**
     * @notice Add a Sub-registry Address to the list of Sub-Registries
     * @param subAssetRegistryAddress Address of the Sub-Registry
     */
    function addSubRegistry(address subAssetRegistryAddress)
        external
        onlyOwner
    {
        require(
            !isSubRegistry[subAssetRegistryAddress],
            "Sub-Registry already exists"
        );
        isSubRegistry[subAssetRegistryAddress] = true;
        subRegistries.push(subAssetRegistryAddress);
    }

    /**
     * @notice Add a new asset to the Main Registry, or overwrite an existing one (if assetsUpdatable is True)
     * @param assetAddress The address of the asset
     * @param assetCreditRatings The List of Credit Rating Categories for the asset for the different BaseCurrencies
     * @dev The list of Credit Ratings should or be as long as the number of baseCurrencies added to the Main Registry,
     *      or the list must have length 0. If the list has length zero, the credit ratings of the asset for all baseCurrencies
     *      is initiated as credit rating with index 0 by default (worst credit rating).
     *      Each Credit Rating Category is labeled with an integer, Category 0 (the default) is for the most risky assets.
     *      Category from 1 to 9 will be used to label groups of assets with similar risk profiles
     *      (Comparable to ratings like AAA, A-, B... for debtors in traditional finance).
     * @dev By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     *      (for instance by changing the oracleaddres to a fake price feed) and poses a security risk towards protocol users.
     *      This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     *      assets are no longer updatable.
     */
    function addAsset(address assetAddress, uint256[] memory assetCreditRatings)
        external
        onlySubRegistry
    {
        if (inMainRegistry[assetAddress]) {
            require(assetsUpdatable, "MR_AA: already known");
        } else {
            inMainRegistry[assetAddress] = true;
            assetsInMainRegistry.push(assetAddress);
        }
        assetToSubRegistry[assetAddress] = msg.sender;

        uint256 assetCreditRatingsLength = assetCreditRatings.length;

        require(
            assetCreditRatingsLength == baseCurrencyCounter ||
                assetCreditRatingsLength == 0,
            "MR_AA: LENGTH_MISMATCH"
        );
        for (uint256 i; i < assetCreditRatingsLength; ) {
            require(
                assetCreditRatings[i] < CREDIT_RATING_CATOGERIES,
                "MR_AA: non-existing"
            );
            assetToBaseCurrencyToCreditRating[assetAddress][
                i
            ] = assetCreditRatings[i];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Change the Credit Rating Category for one or more assets for one or more baseCurrencies
     * @param assets The List of addresses of the assets
     * @param _baseCurrencies The corresponding List of BaseCurrencies
     * @param newCreditRating The corresponding List of new Credit Ratings
     * @dev The function loops over all indexes, and changes for each index the Credit Rating Category of the combination of asset and baseCurrency.
     *      In case multiple Credit Rating Categories for the same assets need to be changed, the address must be repeated in the assets.
     *      Each Credit Rating Category is labeled with an integer, Category 0 (the default) is for the most risky assets.
     *      Category from 1 to 9 will be used to label groups of assets with similar risk profiles
     *      (Comparable to ratings like AAA, A-, B... for debtors in traditional finance).
     */
    function batchSetCreditRating(
        address[] calldata assets,
        uint256[] calldata _baseCurrencies,
        uint256[] calldata newCreditRating
    ) external onlyOwner {
        uint256 assetsLength = assets.length;
        require(
            assetsLength == _baseCurrencies.length &&
                assetsLength == newCreditRating.length,
            "MR_BSCR: LENGTH_MISMATCH"
        );

        for (uint256 i; i < assetsLength; ) {
            require(
                newCreditRating[i] < CREDIT_RATING_CATOGERIES,
                "MR_BSCR: non-existing creditRat"
            );
            assetToBaseCurrencyToCreditRating[assets[i]][
                _baseCurrencies[i]
            ] = newCreditRating[i];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Disables the updatability of assets. In the disabled states, asset properties become immutable
     **/
    function setAssetsToNonUpdatable() external onlyOwner {
        assetsUpdatable = false;
    }

    /**
     * @notice Add a new baseCurrency (a unit in which price is measured, like USD or ETH) to the Main Registry, or overwrite an existing one
     * @param baseCurrencyInformation A Struct with information about the BaseCurrency
     *                              - baseCurrencyToUsdOracleUnit: The unit of the oracle, equal to 10 to the power of the number of decimals of the oracle
     *                              - baseCurrencyUnit: The unit of the baseCurrency, equal to 10 to the power of the number of decimals of the baseCurrency
     *                              - assetAddress: The contract address of the baseCurrency,
     *                              - baseCurrencyToUsdOracle: The contract address of the price oracle of the baseCurrency in USD
     *                              - baseCurrencyLabel: The symbol of the baseCurrency (only used for readability purpose)
     * @param assetCreditRatings The List of the Credit Rating Categories of the baseCurrency, for all the different assets in the Main registry
     * @dev If the BaseCurrency has no native token, baseCurrencyDecimals should be set to 0 and assetAddress to the null address.
     *      Tokens pegged to the native token do not count as native tokens
     *      - USDC is not a native token for USD as BaseCurrency
     *      - WETH is a native token for ETH as BaseCurrency
     * @dev The list of Credit Rating Categories should or be as long as the number of assets added to the Main Registry,
     *      or the list must have length 0. If the list has length zero, the credit ratings of the baseCurrency for all assets
     *      is initiated as credit rating with index 0 by default (worst credit rating).
     *      Each Credit Rating Category is labeled with an integer, Category 0 (the default) is for the most risky assets.
     *      Category from 1 to 9 will be used to label groups of assets with similar risk profiles
     *      (Comparable to ratings like AAA, A-, B... for debtors in traditional finance).
     */
    function addBaseCurrency(
        BaseCurrencyInformation calldata baseCurrencyInformation,
        uint256[] calldata assetCreditRatings
    ) external onlyOwner {
        baseCurrencyToInformation[baseCurrencyCounter] = baseCurrencyInformation;
        assetToBaseCurrency[baseCurrencyInformation.assetAddress] = baseCurrencyCounter;
        isBaseCurrency[baseCurrencyInformation.assetAddress] = true;
        baseCurrencies.push(baseCurrencyInformation.assetAddress);

        uint256 assetCreditRatingsLength = assetCreditRatings.length;
        require(
            assetCreditRatingsLength == assetsInMainRegistry.length ||
                assetCreditRatingsLength == 0,
            "MR_AN: length"
        );
        for (uint256 i; i < assetCreditRatingsLength; ) {
            require(
                assetCreditRatings[i] < CREDIT_RATING_CATOGERIES,
                "MR_AN: non existing credRat"
            );
            assetToBaseCurrencyToCreditRating[assetsInMainRegistry[i]][
                baseCurrencyCounter
            ] = assetCreditRatings[i];
            unchecked {
                ++i;
            }
        }

        unchecked {
            ++baseCurrencyCounter;
        }
    }

    function getTotalValue(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        address baseCurrency
    ) public view returns (uint256 valueInBaseCurrency) {
        valueInBaseCurrency = 
            getTotalValue(
                _assetAddresses,
                _assetIds,
                _assetAmounts,
                assetToBaseCurrency[baseCurrency]
            );
    }

    /**
     * @notice Calculate the total value of a list of assets denominated in a given BaseCurrency
     * @param _assetAddresses The List of token addresses of the assets
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     *      for tokens without Id (ERC20 for instance), the Id should be set to 0
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
            assetAddressesLength == _assetIds.length &&
                assetAddressesLength == _assetAmounts.length,
            "MR_GTV: LENGTH_MISMATCH"
        );
        ISubRegistry.GetValueInput memory getValueInput;
        getValueInput.baseCurrency = baseCurrency;

        for (uint256 i; i < assetAddressesLength; ) {
            address assetAddress = _assetAddresses[i];
            require(inMainRegistry[assetAddress], "MR_GTV: Unknown asset");

            getValueInput.assetAddress = assetAddress;
            getValueInput.assetId = _assetIds[i];
            getValueInput.assetAmount = _assetAmounts[i];

            if (
                assetAddress == baseCurrencyToInformation[baseCurrency].assetAddress
            ) {
                //Should only be allowed if the baseCurrency is ETH, not for stablecoins or wrapped tokens
                valueInBaseCurrency =
                    valueInBaseCurrency +
                    _assetAmounts[i] *
                    baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection; //_assetAmounts can have a variable decimal precision -> bring to 18 decimals
            } else {
                //Calculate value of the next asset and add it to the total value of the vault, both tempValueInUsd and tempValueInBaseCurrency can be non-zero
                (
                    uint256 tempValueInUsd,
                    uint256 tempValueInBaseCurrency
                ) = ISubRegistry(assetToSubRegistry[assetAddress]).getValue(
                        getValueInput
                    );
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
            (, int256 rate, , , ) = IChainLinkData(
                baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracle
            ).latestRoundData();
            //Add valueInUsd to valueInBaseCurrency
            valueInBaseCurrency =
                valueInBaseCurrency +
                valueInUsd.mulDivDown(
                    baseCurrencyToInformation[baseCurrency].baseCurrencyToUsdOracleUnit,
                    uint256(rate)
                );
        }
        //Bring from internal 18 decimals to the number of decimals of baseCurrency
        return valueInBaseCurrency / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection;
    }

    function getListOfValuesPerAsset(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        address baseCurrency
    ) public view returns (uint256[] memory valuesPerAsset) {
        valuesPerAsset = 
            getListOfValuesPerAsset(
                _assetAddresses,
                _assetIds,
                _assetAmounts,
                assetToBaseCurrency[baseCurrency]
            );
    }

    /**
     * @notice Calculate the value per asset of a list of assets denominated in a given BaseCurrency
     * @param _assetAddresses The List of token addresses of the assets
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     *      for tokens without Id (ERC20 for instance), the Id should be set to 0
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
            assetAddressesLength == _assetIds.length &&
                assetAddressesLength == _assetAmounts.length,
            "MR_GLV: LENGTH_MISMATCH"
        );
        ISubRegistry.GetValueInput memory getValueInput;
        getValueInput.baseCurrency = baseCurrency;

        int256 rateBaseCurrencyToUsd;

        for (uint256 i; i < assetAddressesLength; ) {
            address assetAddress = _assetAddresses[i];
            require(inMainRegistry[assetAddress], "MR_GLV: Unknown asset");

            getValueInput.assetAddress = assetAddress;
            getValueInput.assetId = _assetIds[i];
            getValueInput.assetAmount = _assetAmounts[i];

            if (
                assetAddress == baseCurrencyToInformation[baseCurrency].assetAddress
            ) {
                //Should only be allowed if the baseCurrency is ETH, not for stablecoins or wrapped tokens
                valuesPerAsset[i] = _assetAmounts[i];
            } else {
                (uint256 valueInUsd, uint256 valueInBaseCurrency) = ISubRegistry(
                    assetToSubRegistry[assetAddress]
                ).getValue(getValueInput);
                //Check if baseCurrency is USD
                if (baseCurrency == 0) {
                    //Bring from internal 18 decimals to the number of decimals of baseCurrency
                    valuesPerAsset[i] = valueInUsd / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection;
                } else if (valueInBaseCurrency > 0) {
                    //Bring from internal 18 decimals to the number of decimals of baseCurrency
                    valuesPerAsset[i] = valueInBaseCurrency / baseCurrencyToInformation[baseCurrency].baseCurrencyUnitCorrection;
                } else {
                    //Check if the BaseCurrency-USD rate is already fetched
                    if (rateBaseCurrencyToUsd == 0) {
                        //Get the BaseCurrency-USD rate ToDo: Ask via the OracleHub?
                        (, rateBaseCurrencyToUsd, , , ) = IChainLinkData(
                            baseCurrencyToInformation[baseCurrency]
                                .baseCurrencyToUsdOracle
                        ).latestRoundData();
                    }
                    valuesPerAsset[i] = valueInUsd.mulDivDown(
                        baseCurrencyToInformation[baseCurrency]
                            .baseCurrencyToUsdOracleUnit,
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

    function getListOfValuesPerCreditRating(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        address baseCurrency
    ) public view returns (uint256[] memory valuesPerCreditRating) {
        valuesPerCreditRating = 
            getListOfValuesPerCreditRating(
                _assetAddresses,
                _assetIds,
                _assetAmounts,
                assetToBaseCurrency[baseCurrency]
            );
    }

    /**
     * @notice Calculate the value per Credit Rating Category of a list of assets denominated in a given BaseCurrency
     * @param _assetAddresses The List of token addresses of the assets
     * @param _assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     *      for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param _assetAmounts The list of corresponding amounts of each Token-Id combination
     * @param baseCurrency An identifier (uint256) of the BaseCurrency
     * @return valuesPerCreditRating The list of values per Credit Rating Category denominated in BaseCurrency
     * @dev Each Credit Rating Category is labeled with an integer, Category 0 (the default) is for the most risky assets.
     *      Category from 1 to 10 will be used to label groups of assets with similar risk profiles
     *      (Comparable to ratings like AAA, A-, B... for debtors in traditional finance).
     */
    function getListOfValuesPerCreditRating(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        uint256 baseCurrency
    ) public view returns (uint256[] memory valuesPerCreditRating) {
        valuesPerCreditRating = new uint256[](CREDIT_RATING_CATOGERIES);
        uint256[] memory valuesPerAsset = getListOfValuesPerAsset(
            _assetAddresses,
            _assetIds,
            _assetAmounts,
            baseCurrency
        );

        uint256 valuesPerAssetLength = valuesPerAsset.length;
        for (uint256 i; i < valuesPerAssetLength; ) {
            address assetAdress = _assetAddresses[i];
            valuesPerCreditRating[
                assetToBaseCurrencyToCreditRating[assetAdress][baseCurrency]
            ] += valuesPerAsset[i];
            unchecked {
                ++i;
            }
        }

        return valuesPerCreditRating;
    }
}
