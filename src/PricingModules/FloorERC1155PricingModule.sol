/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { PricingModule, IMainRegistry, IOraclesHub } from "./AbstractPricingModule.sol";

/**
 * @title Pricing Module for ERC1155 tokens
 * @author Pragma Labs
 * @notice The FloorERC1155PricingModule stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
 * for the floor price of the collection
 * @dev No end-user should directly interact with the FloorERC1155PricingModule, only the Main-registry, Oracle-Hub or the contract owner
 */
contract FloorERC1155PricingModule is PricingModule {
    mapping(address => AssetInformation) public assetToInformation;

    struct AssetInformation {
        uint256 id;
        address[] oracles;
    }

    /**
     * @notice A Pricing Module must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry_ The address of the Main-registry
     * @param oracleHub_ The address of the Oracle-Hub
     * @param assetType_ Identifier for the type of asset, necessary for the deposit and withdraw logic in the vaults.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     */
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_)
        PricingModule(mainRegistry_, oracleHub_, assetType_, msg.sender)
    { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the FloorERC1155PricingModule.
     * @param asset The contract address of the asset
     * @param id: The id of the collection
     * @param oracles An array of addresses of oracle contracts, to price the asset in USD
     * @param riskVars An array of Risk Variables for the asset
     * @param maxExposure The maximum exposure of the asset in its own decimals
     * @dev Only the Collateral Factor, Liquidation Threshold and basecurrency are taken into account.
     * If no risk variables are provided, the asset is added with the risk variables set to zero, meaning it can't be used as collateral.
     * @dev RiskVarInput.asset can be zero as it is not taken into account.
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added in the Main-Registry as well.
     */
    function addAsset(
        address asset,
        uint256 id,
        address[] calldata oracles,
        RiskVarInput[] calldata riskVars,
        uint256 maxExposure
    ) external onlyOwner {
        //View function, reverts in OracleHub if sequence is not correct
        IOraclesHub(oracleHub).checkOracleSequence(oracles, asset);

        require(!inPricingModule[asset], "PM1155_AA: already added");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        assetToInformation[asset].id = id;
        assetToInformation[asset].oracles = oracles;
        _setRiskVariablesForAsset(asset, riskVars);

        require(maxExposure <= type(uint128).max, "PM1155_AA: Max Exposure not in limits");
        exposure[asset].maxExposure = uint128(maxExposure);

        //Will revert in MainRegistry if asset can't be added
        IMainRegistry(mainRegistry).addAsset(asset, assetType);
    }

    /**
     * @notice Returns the information that is stored in the Pricing Module for a given asset
     * @param asset The Token address of the asset
     * @return id The id of the token
     * @return oracles The list of addresses of the oracles to get the exchange rate of the asset in USD
     */
    function getAssetInformation(address asset) external view returns (uint256, address[] memory) {
        return (assetToInformation[asset].id, assetToInformation[asset].oracles);
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the asset passed as input is whitelisted
     */
    function isAllowListed(address asset, uint256 assetId) public view override returns (bool) {
        if (exposure[asset].maxExposure != 0) {
            if (assetId == assetToInformation[asset].id) {
                return true;
            }
        }

        return false;
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Processes the deposit of a token address and the corresponding Id if it is white-listed
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @param amount the amount of ERC1155 tokens
     * @dev Unsafe cast to uint128, meaning it is assumed no more than 10**(20+decimals) tokens can be deposited
     */
    function processDeposit(address, address asset, uint256 assetId, uint256 amount) external override onlyMainReg {
        require(assetId == assetToInformation[asset].id, "PM1155_PD: ID not allowed");

        exposure[asset].exposure += uint128(amount);
        require(exposure[asset].exposure <= exposure[asset].maxExposure, "PM1155_PD: Exposure not in limits");
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     * - asset: The contract address of the asset
     * - assetId: The Id of the asset
     * - assetAmount: The Amount of tokens
     * - baseCurrency: The BaseCurrency in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInBaseCurrency The value of the asset denominated in BaseCurrency different from USD with 18 Decimals precision
     * @return collateralFactor The Collateral Factor of the asset
     * @return liquidationFactor The Liquidation Factor of the asset
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
        returns (uint256 valueInUsd, uint256 valueInBaseCurrency, uint256 collateralFactor, uint256 liquidationFactor)
    {
        uint256 rateInUsd;
        uint256 rateInBaseCurrency;

        (rateInUsd, rateInBaseCurrency) =
            IOraclesHub(oracleHub).getRate(assetToInformation[getValueInput.asset].oracles, getValueInput.baseCurrency);

        if (rateInBaseCurrency > 0) {
            valueInBaseCurrency = getValueInput.assetAmount * rateInBaseCurrency;
        } else {
            valueInUsd = getValueInput.assetAmount * rateInUsd;
        }

        collateralFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liquidationFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationFactor;
    }
}
