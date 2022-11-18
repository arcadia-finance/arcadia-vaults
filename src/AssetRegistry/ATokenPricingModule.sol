/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractPricingModule.sol";
import "../interfaces/IAToken.sol";
import "../interfaces/IPricingModule.sol";
import "../interfaces/IMainRegistry.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

/**
 * @title Pricing Module for Aave Yield Bearing ERC20 tokens
 * @author Arcadia Finance
 * @notice The ATokenPricingModule stores pricing logic and basic information for yield bearing Aave ERC20 tokens for which a direct price feed exists
 * @dev No end-user should directly interact with the ATokenPricingModule, only the Main-registry, Oracle-Hub or the contract owner
 */
contract ATokenPricingModule is PricingModule {
    using FixedPointMathLib for uint256;

    mapping(address => AssetInformation) public assetToInformation;

    struct AssetInformation {
        uint64 assetUnit;
        address assetAddress;
        address underlyingAssetAddress;
        address[] underlyingAssetOracleAddresses;
    }

    /**
     * @notice A Pricing Module must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry The address of the Main-registry
     * @param oracleHub The address of the Oracle-Hub
     */
    constructor(address mainRegistry, address oracleHub) PricingModule(mainRegistry, oracleHub) {}

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the ATokenPricingModule, or overwrites an existing asset.
     * @param assetAddress The contract address of the asset
     * @param assetCollateralFactors The List of collateral factors for the asset for the different BaseCurrencies
     * @param assetLiquidationThresholds The List of liquidation threshold for the asset for the different BaseCurrencies
     * @dev The list of Risk Variables (Collateral Factor and Liquidation Threshold) should or be as long as
     * the number of assets added to the Main Registry,or the list must have length 0.
     * If the list has length zero, the risk variables of the baseCurrency for all assets
     * is initiated as default (safest lowest rating).
     * Risk variable are variables with decimal by 100
     * @dev The assets are added/overwritten in the Main-Registry as well.
     * By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     * (for instance by changing the oracle address to a fake price feed) and poses a security risk towards protocol users.
     * This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     * assets are no longer updatable.
     * @dev Assets can't have more than 18 decimals.
     */
    function setAssetInformation(
        address assetAddress,
        uint16[] calldata assetCollateralFactors,
        uint16[] calldata assetLiquidationThresholds
    ) external onlyOwner {
        address underlyingAddress = IAToken(assetAddress).UNDERLYING_ASSET_ADDRESS();
        (uint64 assetUnit, address underlyingAssetAddress, address[] memory underlyingAssetOracleAddresses) =
        IPricingModule(IMainRegistry(mainRegistry).assetToPricingModule(underlyingAddress)).getAssetInformation(
            underlyingAddress
        );

        address[] memory tokens = new address[](1);
        tokens[0] = underlyingAssetAddress;

        if (!inPricingModule[assetAddress]) {
            inPricingModule[assetAddress] = true;
            assetsInPricingModule.push(assetAddress);
        }
        assetToInformation[assetAddress].assetAddress = assetAddress;
        assetToInformation[assetAddress].assetUnit = assetUnit;
        assetToInformation[assetAddress].underlyingAssetAddress = underlyingAssetAddress;
        assetToInformation[assetAddress].underlyingAssetOracleAddresses = underlyingAssetOracleAddresses;
        isAssetAddressWhiteListed[assetAddress] = true;
        IMainRegistry(mainRegistry).addAsset(assetAddress, assetCollateralFactors, assetLiquidationThresholds);
    }

    /**
     * @notice Returns the information that is stored in the Pricing Module for a given asset
     * @dev struct is not taken into memory; saves 6613 gas
     * @param asset The Token address of the asset
     * @return assetUnit The number of decimals of the asset
     * @return assetAddress The Token address of the asset
     * @return underlyingAssetAddress The Token address of the underlyting asset
     * @return underlyingAsseOracleoracleAddresses The list of addresses of the oracles to get the exchange rate of the underlying asset in USD
     */
    function getAssetInformation(address asset) external view returns (uint64, address, address, address[] memory) {
        return (
            assetToInformation[asset].assetUnit,
            assetToInformation[asset].assetAddress,
            assetToInformation[asset].underlyingAssetAddress,
            assetToInformation[asset].underlyingAssetOracleAddresses
        );
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param assetAddress The address of the asset
     * @dev Since ERC20 tokens have no Id, the Id should be set to 0
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
     * - assetId: Since ERC20 tokens have no Id, the Id should be set to 0
     * - assetAmount: The Amount of tokens, ERC20 tokens can have any Decimals precision smaller than 18.
     * - baseCurrency: The BaseCurrency (base-asset) in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInBaseCurrency The value of the asset denominated in BaseCurrency different from USD with 18 Decimals precision
     * @dev If the Oracle-Hub returns the rate in a baseCurrency different from USD, the ATokenPricingModule will return
     * the value of the asset in the same BaseCurrency. If the Oracle-Hub returns the rate in USD, the ATokenPricingModule
     * will return the value of the asset in USD.
     * Only one of the two values can be different from 0.
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no check in ATokenPricingModule is necessary, since the check if the asset is whitelisted (and hence added to PricingModule)
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
            assetToInformation[getValueInput.assetAddress].underlyingAssetOracleAddresses, getValueInput.baseCurrency
        );

        if (rateInBaseCurrency > 0) {
            valueInBaseCurrency = (getValueInput.assetAmount).mulDivDown(
                rateInBaseCurrency, assetToInformation[getValueInput.assetAddress].assetUnit
            );
        } else {
            valueInUsd = (getValueInput.assetAmount).mulDivDown(
                rateInUsd, assetToInformation[getValueInput.assetAddress].assetUnit
            );
        }
    }
}
