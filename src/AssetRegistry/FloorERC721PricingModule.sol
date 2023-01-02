/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractPricingModule.sol";

/**
 * @title Pricing Module for ERC721 tokens for which a oracle exists for the floor price of the collection
 * @author Arcadia Finance
 * @notice The FloorERC721PricingModule stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
 * for the floor price of the collection
 * @dev No end-user should directly interact with the FloorERC721PricingModule, only the Main-registry, Oracle-Hub or the contract owner
 */
contract FloorERC721PricingModule is PricingModule {
    mapping(address => AssetInformation) public assetToInformation;

    struct AssetInformation {
        uint256 idRangeStart;
        uint256 idRangeEnd;
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
     * @notice Adds a new asset to the FloorERC721PricingModule.
     * @param asset The contract address of the asset
     * @param idRangeStart: The id of the first NFT of the collection
     * @param idRangeEnd: The id of the last NFT of the collection
     * @param oracles An array of addresses of oracle contracts, to price the asset in USD
     * @param riskVars An array of Risk Variables for the asset
     * @dev Only the Collateral Factor, Liquidation Threshold and basecurrency are taken into account.
     * If no risk variables are provided, the asset is added with the risk variables set to zero, meaning it can't be used as collateral.
     * @dev RiskVarInput.asset can be zero as it is not taken into account.
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added in the Main-Registry as well.
     */
    function addAsset(
        address asset,
        uint256 idRangeStart,
        uint256 idRangeEnd,
        address[] calldata oracles,
        RiskVarInput[] calldata riskVars,
        uint256 maxExposure
    ) external onlyOwner {
        //View function, reverts in OracleHub if sequence is not correct
        IOraclesHub(oracleHub).checkOracleSequence(oracles);

        require(!inPricingModule[asset], "PM721_AA: already added");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        assetToInformation[asset].idRangeStart = idRangeStart;
        assetToInformation[asset].idRangeEnd = idRangeEnd;
        assetToInformation[asset].oracles = oracles;
        _setRiskVariablesForAsset(asset, riskVars);

        isAssetAddressWhiteListed[asset].isWhiteListed = true;
        isAssetAddressWhiteListed[asset].maxExposure = uint248(maxExposure);

        //Will revert in MainRegistry if asset can't be added
        IMainRegistry(mainRegistry).addAsset(asset);
    }

    /**
     * @notice Sets the oracle addresses for the given asset.
     * @param asset The contract address of the asset.
     * @param oracles An array of oracle addresses for the asset.
     */
    function setOracles(address asset, address[] calldata oracles) external onlyOwner {
        require(inPricingModule[asset], "PM721_SO: asset unknown");
        IOraclesHub(oracleHub).checkOracleSequence(oracles);
        assetToInformation[asset].oracles = oracles;
    }

    /**
     * @notice Returns the information that is stored in the Pricing Module for a given asset
     * @dev struct is not taken into memory; saves 6613 gas
     * @param asset The Token address of the asset
     * @return idRangeStart The id of the first token of the collection
     * @return idRangeEnd The id of the last token of the collection
     * @return oracles The list of addresses of the oracles to get the exchange rate of the asset in USD
     */
    function getAssetInformation(address asset) external view returns (uint256, uint256, address[] memory) {
        return (
            assetToInformation[asset].idRangeStart,
            assetToInformation[asset].idRangeEnd,
            assetToInformation[asset].oracles
        );
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
    function isWhiteListed(address asset, uint256 assetId) public view override returns (bool) {
        if (isAssetAddressWhiteListed[asset].isWhiteListed) {
            if (isIdInRange(asset, assetId)) {
                return true;
            }
        }

        return false;
    }

    function processDeposit(address asset, uint256 assetId, uint256 amount) external returns (bool success) {
        isAssetAddressWhiteListed[asset].maxExposure -= uint248(amount);
        return isWhiteListed(asset, assetId);
    }

    /**
     * @notice Checks if the Id for a given token is in the range for which there exists a price feed
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the Id of the given asset is whitelisted
     */
    function isIdInRange(address asset, uint256 assetId) private view returns (bool) {
        if (assetId >= assetToInformation[asset].idRangeStart && assetId <= assetToInformation[asset].idRangeEnd) {
            return true;
        } else {
            return false;
        }
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     * - assetAddress: The contract address of the asset
     * - assetId: The Id of the asset
     * - assetAmount: Since ERC721 tokens have no amount, the amount should be set to 0
     * - baseCurrency: The BaseCurrency (base-asset) in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInBaseCurrency The value of the asset denominated in BaseCurrency different from USD with 18 Decimals precision
     * @dev If the Oracle-Hub returns the rate in a baseCurrency different from USD, the FloorERC721PricingModule will return
     * the value of the asset in the same BaseCurrency. If the Oracle-Hub returns the rate in USD, the FloorERC721PricingModule
     * will return the value of the asset in USD.
     * Only one of the two values can be different from 0.
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no check in FloorERC721PricingModule is necessary, since the check if the asset is whitelisted (and hence added to PricingModule)
     * is already done in the Main-Registry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 valueInBaseCurrency, uint256 collFactor, uint256 liqThreshold)
    {
        (valueInUsd, valueInBaseCurrency) =
            IOraclesHub(oracleHub).getRate(assetToInformation[getValueInput.asset].oracles, getValueInput.baseCurrency);

        collFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liqThreshold = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationThreshold;
    }
}
