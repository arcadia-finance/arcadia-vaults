/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { PricingModule, IPricingModule } from "./AbstractPricingModule.sol";
import { IOraclesHub } from "./interfaces/IOraclesHub.sol";
import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IStandardERC20PricingModule } from "./interfaces/IStandardERC20PricingModule.sol";
/**
 * @title Sub-registry for Standard ERC20 tokens
 * @author Arcadia Finance
 * @notice The StandardERC20PricingModule stores pricing logic and basic information for ERC20 tokens for which a direct price feed exists
 * @dev No end-user should directly interact with the StandardERC20PricingModule, only the Main-registry, Oracle-Hub or the contract owner
 */

contract StandardERC20PricingModule is PricingModule, IStandardERC20PricingModule {
    using FixedPointMathLib for uint256;

    mapping(address => AssetInformation) public assetToInformation;

    struct AssetInformation {
        uint64 assetUnit;
        address[] oracles;
    }

    /**
     * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry_ The address of the Main-registry
     * @param oracleHub_ The address of the Oracle-Hub
     */
    constructor(address mainRegistry_, address oracleHub_) PricingModule(mainRegistry_, oracleHub_, msg.sender) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the StandardERC20PricingModule.
     * @param asset The contract address of the asset
     * @param oracles An array of addresses of oracle contracts, to price the asset in USD
     * @param riskVars An array of Risk Variables for the asset
     * @param maxExposure The maximum exposure of the asset in its own decimals
     * @dev Only the Collateral Factor, Liquidation Threshold and Base Currency are taken into account.
     * If no risk variables are provided, the asset is added with the risk variables set to zero, meaning it can't be used as collateral.
     * @dev RiskVarInput.asset can be zero as it is not taken into account.
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added in the Main-Registry as well.
     * @dev Assets can't have more than 18 decimals.
     */
    function addAsset(address asset, address[] calldata oracles, RiskVarInput[] calldata riskVars, uint128 maxExposure)
        external
        onlyOwner
    {
        require(!inPricingModule[asset], "PM20_AA: already added");
        //View function, reverts in OracleHub if sequence is not correct
        IOraclesHub(oracleHub).checkOracleSequence(oracles, asset);

        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        uint256 assetUnit = 10 ** IERC20(asset).decimals();
        require(assetUnit <= 1e18, "PM20_AA: Maximal 18 decimals");

        assetToInformation[asset].assetUnit = uint64(assetUnit); //Can safely cast to uint64, we previously checked it is smaller than 10e18
        assetToInformation[asset].oracles = oracles;
        _setRiskVariablesForAsset(asset, riskVars);

        exposure[asset].maxExposure = maxExposure;

        //Will revert in MainRegistry if asset can't be added
        IMainRegistry(mainRegistry).addAsset(asset);
    }

    /**
     * @notice Returns the information that is stored in the StandardERC20PricingModule for a given ERC20 token.
     * @param asset The Token address of the asset.
     * @return assetUnit The unit (10 ** decimals) of the asset.
     * @return oracles The list of addresses of the oracles to get the exchange rate of the asset in USD.
     */
    function getAssetInformation(address asset) external view returns (uint64, address[] memory) {
        return (assetToInformation[asset].assetUnit, assetToInformation[asset].oracles);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     * - asset: The contract address of the asset
     * - assetId: Since ERC20 tokens have no Id, the Id should be set to 0
     * - assetAmount: The Amount of tokens, ERC20 tokens can have any Decimals precision smaller than 18.
     * - baseCurrency: The BaseCurrency in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInBaseCurrency The value of the asset denominated in BaseCurrency different from USD with 18 Decimals precision
     * @return collateralFactor The Collateral Factor of the asset
     * @return liquidationFactor The Liquidation Factor of the asset
     * @dev If the Oracle-Hub returns the rate in a baseCurrency different from USD, the StandardERC20PricingModule will return
     * the value of the asset in the same BaseCurrency. If the Oracle-Hub returns the rate in USD, the StandardERC20PricingModule
     * will return the value of the asset in USD.
     * Only one of the two values can be different from 0.
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
     * @dev If the asset is not added to PricingModule this function will return value 0 without throwing an error.
     * However no check in StandardERC20PricingModule is necessary, since the check if the asset is allow listed (and hence added to PricingModule)
     * is already done in the Main-Registry.
     */
    function getValue(IPricingModule.GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 valueInBaseCurrency, uint256 collateralFactor, uint256 liquidationFactor)
    {
        uint256 rateInUsd;
        uint256 rateInBaseCurrency;

        (rateInUsd, rateInBaseCurrency) =
            IOraclesHub(oracleHub).getRate(assetToInformation[getValueInput.asset].oracles, getValueInput.baseCurrency);

        if (rateInBaseCurrency > 0) {
            valueInBaseCurrency = (getValueInput.assetAmount).mulDivDown(
                rateInBaseCurrency, assetToInformation[getValueInput.asset].assetUnit
            );
        } else {
            valueInUsd =
                (getValueInput.assetAmount).mulDivDown(rateInUsd, assetToInformation[getValueInput.asset].assetUnit);
        }

        collateralFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liquidationFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationFactor;
    }
}
