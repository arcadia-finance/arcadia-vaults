/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IOraclesHub} from "./interfaces/IOraclesHub.sol";
import {IMainRegistry} from "./interfaces/IMainRegistry.sol";
import {RiskConstants} from "../utils/RiskConstants.sol";

/**
 * @title Abstract Pricing Module
 * @author Arcadia Finance
 * @notice Sub-Registries have the pricing logic and basic information for tokens that can, or could at some point, be deposited in the vaults
 * @dev No end-user should directly interact with Sub-Registries, only the Main Registry, Oracle-Hub or the contract owner
 * @dev This abstract contract contains the minimal functions that each Pricing Module should have to properly work with the Main Registry
 */
abstract contract PricingModule is Ownable {
    address public immutable mainRegistry;
    address public immutable oracleHub;
    address public riskManager;

    address[] public assetsInPricingModule;

    mapping(address => bool) public inPricingModule;
    mapping(address => Exposure) public exposure;
    mapping(address => mapping(uint256 => RiskVars)) public assetRiskVars;

    //struct with input variables necessary to avoid stack too deep error
    struct GetValueInput {
        address asset;
        uint256 assetId;
        uint256 assetAmount;
        uint256 baseCurrency;
    }

    struct Exposure {
        uint128 maxExposure;
        uint128 exposure;
    }

    struct RiskVars {
        uint16 collateralFactor;
        uint16 liquidationFactor;
    }

    struct RiskVarInput {
        address asset;
        uint8 baseCurrency;
        uint16 collateralFactor;
        uint16 liquidationFactor;
    }

    modifier onlyRiskManager() {
        require(msg.sender == riskManager, "APM: ONLY_RISK_MANAGER");
        _;
    }

    modifier onlyMainReg() {
        require(msg.sender == mainRegistry, "APM: ONLY_MAIN_REGISTRY");
        _;
    }

    /**
     * @notice A Pricing Module must always be initialised with the address of the Main Registry and the Oracle-Hub
     * @param mainRegistry_ The address of the Main Registry
     * @param oracleHub_ The address of the Oracle-Hub
     * @param riskManager_ The address of the Risk Manager
     */
    constructor(address mainRegistry_, address oracleHub_, address riskManager_) {
        mainRegistry = mainRegistry_;
        oracleHub = oracleHub_;
        riskManager = riskManager_;
    }

    /*///////////////////////////////////////////////////////////////
                    RISK MANAGER MANAGEMENT
    ///////////////////////////////////////////////////////////////*/
    /**
     * @notice Sets a new Risk Manager
     * @param riskManager_ The address of the new Risk Manager
     */
    function setRiskManager(address riskManager_) external onlyOwner {
        riskManager = riskManager_;
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param asset The address of the asset
     * @dev For assets without Id (ERC20, ERC4626...), the Id should be set to 0
     * @return A boolean, indicating if the asset passed as input is whitelisted
     */
    function isAllowListed(address asset, uint256) public view virtual returns (bool) {
        return exposure[asset].maxExposure != 0;
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @dev The value of the asset can be denominated in:
     * - USD.
     * - A given BaseCurrency, different from USD.
     * - A combination of USD and a given BaseCurrency, different from USD (will be very exceptional,
     * but theoratically possible for eg. a UNI V2 LP position of two underlying assets,
     * one denominated in USD and the other one in the different BaseCurrency).
     * @dev All price feeds should be fetched in the Oracle-Hub
     */
    function getValue(GetValueInput memory) public view virtual returns (uint256, uint256, uint256, uint256) {}

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk variables of an asset
     * @param asset The address of the asset
     * @return assetCollateralFactors The collateral factor for the asset
     * @return assetLiquidationFactors The liquidation factor for the asset
     */
    function getRiskVariables(address asset, uint256 baseCurrency) public view virtual returns (uint16, uint16) {
        return
            (assetRiskVars[asset][baseCurrency].collateralFactor, assetRiskVars[asset][baseCurrency].liquidationFactor);
    }

    /**
     * @notice Sets the risk variables for a batch of assets.
     * @param riskVarInputs An array of risk variable inputs for the assets.
     * @dev Risk variable are variables with 2 decimals precision
     * @dev Can only be called by the Risk Manager
     */
    function setBatchRiskVariables(RiskVarInput[] memory riskVarInputs) public virtual onlyRiskManager {
        uint256 baseCurrencyCounter = IMainRegistry(mainRegistry).baseCurrencyCounter();
        uint256 riskVarInputsLength = riskVarInputs.length;

        for (uint256 i; i < riskVarInputsLength;) {
            require(riskVarInputs[i].baseCurrency < baseCurrencyCounter, "APM_SBRV: BaseCur. not in limits");

            _setRiskVariables(
                riskVarInputs[i].asset,
                riskVarInputs[i].baseCurrency,
                RiskVars({
                    collateralFactor: riskVarInputs[i].collateralFactor,
                    liquidationFactor: riskVarInputs[i].liquidationFactor
                })
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Sets risk variables for the asset specified
     * @param asset The address of the asset
     * @param riskVarInputs Array of RiskVarInput structs with all the required risk variables
     */
    function _setRiskVariablesForAsset(address asset, RiskVarInput[] memory riskVarInputs) internal virtual {
        uint256 baseCurrencyCounter = IMainRegistry(mainRegistry).baseCurrencyCounter();
        uint256 riskVarInputsLength = riskVarInputs.length;

        for (uint256 i; i < riskVarInputsLength;) {
            require(baseCurrencyCounter > riskVarInputs[i].baseCurrency, "APM_SRVFA: BaseCur not in limits");
            _setRiskVariables(
                asset,
                riskVarInputs[i].baseCurrency,
                RiskVars({
                    collateralFactor: riskVarInputs[i].collateralFactor,
                    liquidationFactor: riskVarInputs[i].liquidationFactor
                })
            );

            unchecked {
                ++i;
            }
        }
    }

    function _setRiskVariables(address asset, uint256 baseCurrency, RiskVars memory riskVars) internal virtual {
        require(riskVars.collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR, "APM_SRV: Coll.Fact not in limits");
        require(riskVars.liquidationFactor <= RiskConstants.MAX_LIQUIDATION_FACTOR, "APM_SRV: Liq.Fact not in limits");

        assetRiskVars[asset][baseCurrency] = riskVars;
    }

    /**
     * @notice Set the maximum exposure for an asset
     * @param asset The address of the asset
     * @param maxExposure The maximum exposure for the asset
     * @dev This function can only be called by the risk manager. It sets the maximum exposure for the given asset in the exposure mapping.
     */
    function setExposureOfAsset(address asset, uint256 maxExposure) public virtual onlyRiskManager {
        require(maxExposure <= type(uint128).max, "APM_SEA: Max Exp. not in limits");
        exposure[asset].maxExposure = uint128(maxExposure);
    }

    /**
     * @notice Processes the deposit of tokens if it is white-listed
     * @param asset The address of the asset
     * param assetId The Id of the asset where applicable
     * @param amount The amount of tokens
     * @dev Unsafe cast to uint128, meaning it is assumed no more than 10**(20+decimals) tokens can be deposited
     */
    function processDeposit(address asset, uint256, uint256 amount) external virtual onlyMainReg {
        require(
            exposure[asset].exposure + uint128(amount) <= exposure[asset].maxExposure, "APM_PD: Exposure not in limits"
        );
        exposure[asset].exposure += uint128(amount);
    }

    /**
     * @notice Processes the withdrawal of tokens to increase the maxExposure
     * @param asset The address of the asset
     * @param amount the amount of tokens
     * @dev Unsafe cast to uint128, meaning it is assumed no more than 10**(20+decimals) tokens will ever be deposited
     */
    function processWithdrawal(address asset, uint256 amount) external virtual onlyMainReg {
        exposure[asset].exposure -= uint128(amount);
    }
}
