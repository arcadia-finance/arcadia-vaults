/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractPricingModule.sol";

/**
 * @title Pricing Module for ERC1155 tokens
 * @author Arcadia Finance
 * @notice The FloorERC1155PricingModule stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
 * for the floor price of the collection
 * @dev No end-user should directly interact with the FloorERC1155PricingModule, only the Main-registry, Oracle-Hub or the contract owner
 */
contract FloorERC1155PricingModule is PricingModule {
    mapping(address => AssetInformation) public assetToInformation;

    struct AssetInformation {
        uint256 id;
        address assetAddress;
        uint16[] assetCollateralFactors;
        uint16[] assetLiquidationThresholds;
        address[] oracleAddresses;
    }

    /**
     * @notice A Pricing Module must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry_ The address of the Main-registry
     * @param oracleHub_ The address of the Oracle-Hub
     */
    constructor(address mainRegistry_, address oracleHub_) PricingModule(mainRegistry_, oracleHub_) {}

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the FloorERC1155PricingModule, or overwrites an existing one.
     * @param assetInformation A Struct with information about the asset
     * - id: The Id of the asset
     * - assetAddress: The contract address of the asset
     * - assetCollateralFactors: The List of collateral factors for the asset for the different BaseCurrencies
     * - assetLiquidationThresholds: The List of liquidation thresholds for the asset for the different BaseCurrencies
     * - oracleAddresses: An array of addresses of oracle contracts, to price the asset in USD
     * @dev The list of Risk Variables (Collateral Factor and Liquidation Threshold) should either be as long as
     * the number of assets added to the Main Registry,or the list must have length 0.
     * If the list has length zero, the risk variables of the baseCurrency for all assets
     * is initiated as default (safest lowest rating).
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added/overwritten in the Main-Registry as well.
     * By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     * (for instance by changing the oracleaddres to a fake price feed) and poses a security risk towards protocol users.
     * This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     * assets are no longer updatable.
     */
    function setAssetInformation(
        AssetInformation memory assetInformation
    ) external onlyOwner {

        //no asset units

        address assetAddress = assetInformation.assetAddress;

        IOraclesHub(oracleHub).checkOracleSequence(assetInformation.oracleAddresses);

        if (!inPricingModule[assetAddress]) {
            inPricingModule[assetAddress] = true;
            assetsInPricingModule.push(assetAddress);
        }

        assetToInformation[assetAddress].id = assetInformation.id;
        assetToInformation[assetAddress].assetAddress = assetAddress;
        assetToInformation[assetAddress].oracleAddresses = assetInformation.oracleAddresses;
        _storeRiskVariables(assetAddress, assetInformation.assetCollateralFactors, assetInformation.assetLiquidationThresholds);

        isAssetAddressWhiteListed[assetAddress] = true;

        require(IMainRegistry(mainRegistry).addAsset(assetAddress), "PM1155_SAI: Unable to add in MR");
    }

    function _storeRiskVariables(address assetAddress, uint16[] memory assetCollateralFactors, uint16[] memory assetLiquidationThresholds) internal override {

        // Check: Valid length of arrays
        uint256 baseCurrencyCounter = IMainRegistry(mainRegistry).baseCurrencyCounter();
        uint256 assetCollateralFactorsLength = assetCollateralFactors.length;
        require(
            (assetCollateralFactorsLength == baseCurrencyCounter
                && assetCollateralFactorsLength == assetLiquidationThresholds.length) 
            || 
            (assetCollateralFactorsLength == 0 && assetLiquidationThresholds.length == 0),
            "PM20_SRV: LENGTH_MISMATCH"
        );

        // Logic Fork: If the list are empty, initate the variables with default collateralFactor and liquidationThreshold
        if (assetCollateralFactorsLength == 0) {
            // Loop: Per base currency
            for (uint256 i; i < baseCurrencyCounter;) {
                // Write: Default variables for collateralFactor and liquidationThreshold
                // make in memory, store once
                assetCollateralFactors[i] = DEFAULT_COLLATERAL_FACTOR;
                assetLiquidationThresholds[i] = DEFAULT_LIQUIDATION_THRESHOLD;

                unchecked {
                    i++;
                }
            }

            assetToInformation[assetAddress].assetCollateralFactors = assetCollateralFactors;
            assetToInformation[assetAddress].assetLiquidationThresholds = assetLiquidationThresholds;

        } else {
                // Loop: Per value of collateral factor and liquidation threshold
                for (uint256 i; i < assetCollateralFactorsLength;) {
                    // Check: Values in the allowed limit
                    require(
                        assetCollateralFactors[i] <= MAX_COLLATERAL_FACTOR && assetCollateralFactors[i] >= MIN_COLLATERAL_FACTOR,
                        "PM20_SRV: Coll.Fact not in limits"
                    );
                    require(
                        assetLiquidationThresholds[i] <= MAX_LIQUIDATION_THRESHOLD
                            && assetLiquidationThresholds[i] >= MIN_LIQUIDATION_THRESHOLD,
                        "PM20_SRV: Liq.Thres not in limits"
                    );

                    unchecked {
                        i++;
                    }
                }

                assetToInformation[assetAddress].assetCollateralFactors = assetCollateralFactors;
                assetToInformation[assetAddress].assetLiquidationThresholds = assetLiquidationThresholds;

        }
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param assetAddress The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the asset passed as input is whitelisted
     */
    function isWhiteListed(address assetAddress, uint256 assetId) external view override returns (bool) {
        if (isAssetAddressWhiteListed[assetAddress]) {
            if (assetId == assetToInformation[assetAddress].id) {
                return true;
            }
        }

        return false;
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     * - assetAddress: The contract address of the asset
     * - assetId: The Id of the asset
     * - assetAmount: The Amount of tokens
     * - baseCurrency: The BaseCurrency (base-asset) in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInBaseCurrency The value of the asset denominated in BaseCurrency different from USD with 18 Decimals precision
     * @dev If the Oracle-Hub returns the rate in a baseCurrency different from USD, the FloorERC1155PricingModule will return
     * the value of the asset in the same BaseCurrency. If the Oracle-Hub returns the rate in USD, the FloorERC1155PricingModule
     * will return the value of the asset in USD.
     * Only one of the two values can be different from 0.
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no check in FloorERC1155PricingModule is necessary, since the check if the asset is whitelisted (and hence added to PricingModule)
     * is already done in the Main-Registry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 valueInBaseCurrency, uint256 collFactor, uint256 liqThreshold)
    {
        uint256 rateInUsd;
        uint256 rateInBaseCurrency;

        (rateInUsd, rateInBaseCurrency) = IOraclesHub(oracleHub).getRate(
            assetToInformation[getValueInput.assetAddress].oracleAddresses, getValueInput.baseCurrency
        );

        if (rateInBaseCurrency > 0) {
            valueInBaseCurrency = getValueInput.assetAmount * rateInBaseCurrency;
        } else {
            valueInUsd = getValueInput.assetAmount * rateInUsd;
        }

        collFactor = assetToInformation[getValueInput.assetAddress].assetCollateralFactors[getValueInput.baseCurrency];
        liqThreshold = assetToInformation[getValueInput.assetAddress].assetLiquidationThresholds[getValueInput.baseCurrency];
    }
}
