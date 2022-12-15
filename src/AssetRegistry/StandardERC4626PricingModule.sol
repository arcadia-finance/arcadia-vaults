/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractPricingModule.sol";
import "../interfaces/IERC4626.sol";
import "../interfaces/IPricingModule.sol";
import "../interfaces/IMainRegistry.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

/**
 * @title Sub-registry for Standard ERC4626 tokens
 * @author Arcadia Finance
 * @notice The StandardERC4626Registry stores pricing logic and basic information for ERC4626 tokens for which the underlying assets have direct price feed.
 * @dev No end-user should directly interact with the StandardERC4626Registry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract StandardERC4626PricingModule is PricingModule {
    using FixedPointMathLib for uint256;

    mapping(address => AssetInformation) public assetToInformation;

    struct AssetInformation {
        uint64 assetUnit;
        address underlyingAsset;
        address[] underlyingAssetOracles;
    }

    /**
     * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry_ The address of the Main-registry
     * @param oracleHub_ The address of the Oracle-Hub
     */
    constructor(address mainRegistry_, address oracleHub_) PricingModule(mainRegistry_, oracleHub_) {}

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the ATokenPricingModule, or overwrites an existing asset.
     * @param asset The contract address of the asset
     * @param assetCollateralFactors: The List of collateral factors for the asset for the different BaseCurrencies
     * @param assetLiquidationThresholds The List of liquidation thresholds for the asset for the different BaseCurrencies
     * @dev The list of Risk Variables (Collateral Factor and Liquidation Threshold) should either be as long as
     * the number of assets added to the Main Registry,or the list must have length 0.
     * If the list has length zero, the risk variables of the baseCurrency for all assets
     * is initiated as default (safest lowest rating).
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added/overwritten in the Main-Registry as well.
     * By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     * (for instance by changing the oracle address to a fake price feed) and poses a security risk towards protocol users.
     * This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     * assets are no longer updatable.
     * @dev Assets can't have more than 18 decimals.
     */
    function addAsset(address asset, 
                                 RiskVarInput[] calldata assetCollateralFactors, 
                                 RiskVarInput[] calldata assetLiquidationThresholds) external onlyOwner {
        
        uint256 assetUnit = 10 ** IERC4626(asset).decimals();
        require(assetUnit <= 1000000000000000000, "PM4626_SAI: Maximal 18 decimals");


        address underlyingAsset = address(IERC4626(asset).asset());
        (uint64 underlyingAssetUnit,, address[] memory underlyingAssetOracles) = IPricingModule(
            IMainRegistry(mainRegistry).assetToPricingModule(underlyingAsset)
        ).getAssetInformation(underlyingAsset);

        require(10 ** IERC4626(asset).decimals() == underlyingAssetUnit, "PM4626_SAI: Decimals don't match");
        //

        //we can skip the oracle addresses check, already checked on underlying asset

        require(!inPricingModule[asset], "PM4626_SAI: already added");        
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        assetToInformation[asset].assetUnit = uint64(assetUnit);
        assetToInformation[asset].underlyingAsset = underlyingAsset;
        assetToInformation[asset].underlyingAssetOracles = underlyingAssetOracles;
        _setRiskVariables(
            asset, assetCollateralFactors, assetLiquidationThresholds
        );

        isAssetAddressWhiteListed[asset] = true;

        require(IMainRegistry(mainRegistry).addAsset(asset), "PM4626_SAI: Unable to add in MR");
    }

    function syncOracles(address asset) external {
        (,, address[] memory underlyingAssetOracles) = IPricingModule(
            IMainRegistry(mainRegistry).assetToPricingModule(assetToInformation[asset].underlyingAsset)
        ).getAssetInformation(assetToInformation[asset].underlyingAsset);
        assetToInformation[asset].underlyingAssetOracles = underlyingAssetOracles;
    }

    /**
     * @notice Returns the information that is stored in the Sub-registry for a given asset
     * @dev struct is not taken into memory; saves 6613 gas
     * @param asset The Token address of the asset
     * @return assetDecimals The number of decimals of the asset
     * @return underlyingAssetAddress The Token address of the underlying asset
     * @return underlyingAssetOracles The list of addresses of the oracles to get the exchange rate of the underlying asset in USD
     */
    function getAssetInformation(address asset) external view returns (uint64, address, address[] memory) {
        return (
            assetToInformation[asset].assetUnit,
            assetToInformation[asset].underlyingAsset,
            assetToInformation[asset].underlyingAssetOracles
        );
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param assetAddress The address of the asset
     * @dev Since ERC4626 tokens have no Id, the Id should be set to 0
     * @return A boolean, indicating if the asset passed as input is whitelisted
     */
    function isWhiteListed(address assetAddress, uint256) external view override returns (bool) {
        if (isAssetAddressWhiteListed[assetAddress]) {
            return true;
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
     * - assetId: Since ERC4626 tokens have no Id, the Id should be set to 0
     * - assetAmount: The Amount of Shares, ERC4626 tokens can have any Decimals precision smaller than 18.
     * - baseCurrency: The BaseCurrency (base-asset) in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInBaseCurrency The value of the asset denominated in BaseCurrency different from USD with 18 Decimals precision
     * @dev If the Oracle-Hub returns the rate in a baseCurrency different from USD, the StandardERC4626Registry will return
     * the value of the asset in the same BaseCurrency. If the Oracle-Hub returns the rate in USD, the StandardERC4626Registry
     * will return the value of the asset in USD.
     * Only one of the two values can be different from 0.
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no check in StandardERC4626Registry is necessary, since the check if the asset is whitelisted (and hence added to PricingModule)
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
            assetToInformation[getValueInput.asset].underlyingAssetOracles, getValueInput.baseCurrency
        );

        uint256 assetAmount = IERC4626(getValueInput.asset).convertToAssets(getValueInput.assetAmount);
        if (rateInBaseCurrency > 0) {
            valueInBaseCurrency =
                assetAmount.mulDivDown(rateInBaseCurrency, assetToInformation[getValueInput.asset].assetUnit);
        } else {
            valueInUsd = assetAmount.mulDivDown(rateInUsd, assetToInformation[getValueInput.asset].assetUnit);
        }

        collFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liqThreshold = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationThreshold;
    }
}
