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
        address[] oracles;
    }

    /**
     * @notice A Pricing Module must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry_ The address of the Main-registry
     * @param oracleHub_ The address of the Oracle-Hub
     */
    constructor(address mainRegistry_, address oracleHub_) PricingModule(mainRegistry_, oracleHub_, msg.sender) {}

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the FloorERC1155PricingModule, or overwrites an existing one.
     * @param asset The contract address of the asset
     * @param id: The id of the collection
     * @param oracles An array of addresses of oracle contracts, to price the asset in USD
     * @param riskVars An array of Risk Variables (Collateral Factor and Liquidation Threshold) for the asset
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
    function addAsset(
        address asset,
        uint256 id,
        address[] calldata oracles,
        RiskVarInput[] calldata riskVars
    ) external onlyOwner {
        //no asset units

        IOraclesHub(oracleHub).checkOracleSequence(oracles);

        require(!inPricingModule[asset], "PM1155_AA: already added");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        assetToInformation[asset].id = id;
        assetToInformation[asset].oracles = oracles;
        _setRiskVariablesForAsset(asset, riskVars);

        isAssetAddressWhiteListed[asset] = true;

        require(IMainRegistry(mainRegistry).addAsset(asset), "PM1155_AA: Unable to add in MR");
    }

    function setOracles(address asset, address[] calldata oracles) external onlyOwner {
        require(inPricingModule[asset], "PM20_AA: asset unknown");
        IOraclesHub(oracleHub).checkOracleSequence(oracles);
        assetToInformation[asset].oracles = oracles;
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

        (rateInUsd, rateInBaseCurrency) =
            IOraclesHub(oracleHub).getRate(assetToInformation[getValueInput.asset].oracles, getValueInput.baseCurrency);

        if (rateInBaseCurrency > 0) {
            valueInBaseCurrency = getValueInput.assetAmount * rateInBaseCurrency;
        } else {
            valueInUsd = getValueInput.assetAmount * rateInUsd;
        }

        collFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liqThreshold = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationThreshold;
    }
}
