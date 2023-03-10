/**
 * Created by Pragma Labs
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
 * @title Pricing Module for Standard ERC20 tokens.
 * @author Pragma Labs
 * @notice The pricing logic and basic information for ERC20 tokens for which a direct price feed exists.
 * @dev No end-user should directly interact with the StandardERC20PricingModule, only the Main-registry,
 * Oracle-Hub or the contract owner.
 */
contract StandardERC20PricingModule is PricingModule, IStandardERC20PricingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map asset => assetInformation.
    mapping(address => AssetInformation) public assetToInformation;

    // Struct with additional information for a specific asset.
    struct AssetInformation {
        uint64 assetUnit; // The unit of the asset, equal to 10^decimals.
        address[] oracles; // Array of contract addresses of oracles.
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The contract address of the MainRegistry.
     * @param oracleHub_ The contract address of the OracleHub.
     * @param assetType_ Identifier for the token standard of the asset.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     */
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_)
        PricingModule(mainRegistry_, oracleHub_, assetType_, msg.sender)
    { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the StandardERC20PricingModule.
     * @param asset The contract address of the asset.
     * @param oracles An array of contract addresses of oracles, to price the asset in USD.
     * @param riskVars An array of RiskVarInput structs.
     * @param maxExposure The maximum protocol wide exposure to the asset.
     * @dev Assets can't have more than 18 decimals.
     * @dev The asset slot in the RiskVarInput struct can be any value as it is not used in this function.
     * @dev If no risk variables are provided, the asset is added with the risk variables set by default to zero,
     * resulting in the asset being valued at 0.
     * @dev Risk variables are variables with 2 decimals precision.
     */
    function addAsset(address asset, address[] calldata oracles, RiskVarInput[] calldata riskVars, uint128 maxExposure)
        external
        onlyOwner
    {
        require(!inPricingModule[asset], "PM20_AA: already added");
        // View function, reverts in OracleHub if sequence is not correct.
        IOraclesHub(oracleHub).checkOracleSequence(oracles, asset);

        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        uint256 assetUnit = 10 ** IERC20(asset).decimals();
        require(assetUnit <= 1e18, "PM20_AA: Maximal 18 decimals");

        // Can safely cast to uint64, we previously checked it is smaller than 10e18.
        assetToInformation[asset].assetUnit = uint64(assetUnit);
        assetToInformation[asset].oracles = oracles;
        _setRiskVariablesForAsset(asset, riskVars);

        exposure[asset].maxExposure = maxExposure;

        emit MaxExposureSet(asset, maxExposure);

        // Will revert in MainRegistry if asset can't be added.
        IMainRegistry(mainRegistry).addAsset(asset, assetType);
    }

    /**
     * @notice Sets a new oracle sequence in the case one of the current oracles is decommissioned.
     * @param asset The contract address of the asset.
     * @param newOracles An array of contract addresses of oracles, to price the asset in USD.
     * @param decommissionedOracle The contract address of the decommissioned oracle.
     */
    function setOracles(address asset, address[] calldata newOracles, address decommissionedOracle)
        external
        onlyOwner
    {
        // If asset is not added to the Pricing Module, oldOracles will have length 0,
        // in this case the for loop will be skipped and the function will revert.
        address[] memory oldOracles = assetToInformation[asset].oracles;
        uint256 oraclesLength = oldOracles.length;
        for (uint256 i; i < oraclesLength;) {
            if (oldOracles[i] == decommissionedOracle) {
                require(!IOraclesHub(oracleHub).isActive(oldOracles[i]), "PM20_SO: Oracle still active");
                // View function, reverts in OracleHub if sequence is not correct.
                IOraclesHub(oracleHub).checkOracleSequence(newOracles, asset);
                assetToInformation[asset].oracles = newOracles;
                return;
            }
            unchecked {
                ++i;
            }
        }
        // We only arrive in tis state if length of oldOracles was zero, or decommissionedOracle was not in the oldOracles array.
        // -> reverts.
        revert("PM20_SO: Unknown Oracle");
    }

    /**
     * @notice Returns the asset information of an asset.
     * @param asset The contract address of the asset.
     * @return assetUnit The unit (10^decimals) of the asset.
     * @return oracles An array of contract addresses of oracles, to price the asset in USD.
     */
    function getAssetInformation(address asset) external view returns (uint64, address[] memory) {
        return (assetToInformation[asset].assetUnit, assetToInformation[asset].oracles);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency.
     * @param getValueInput A Struct with the input variables (avoid stack to deep).
     * - asset: The contract address of the asset.
     * - assetId: Since ERC20 tokens have no Id, the Id should be set to 0.
     * - assetAmount: The amount of assets.
     * - baseCurrency: The BaseCurrency in which the value is ideally denominated.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return valueInBaseCurrency The value of the asset denominated in a BaseCurrency different from USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @return liquidationFactor liquidationFactor The liquidation factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @dev If the OracleHub returns the rate in a baseCurrency different from USD, the StandardERC20PricingModule will return
     * the value of the asset in the same BaseCurrency. If the Oracle-Hub returns the rate in USD, the StandardERC20PricingModule
     * will return the value of the asset in USD.
     * Only one of the two values can be different from 0.
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
     * @dev If the asset is not added to PricingModule, this function will return value 0 without throwing an error.
     * However no check in StandardERC20PricingModule is necessary, since the check if the asset is allow listed (and hence added to PricingModule)
     * is already done in the Main$Registry.
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
