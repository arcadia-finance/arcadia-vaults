/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractPricingModule.sol";

/**
 * @title Test Pricing Logic for ERC1155 tokens
 * @author Arcadia Finance
 * @notice The FloorERC1155PricingModule stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
 * for the floor price of the collection
 * @dev No end-user should directly interact with the FloorERC1155PricingModule, only the Main-registry, Oracle-Hub or the contract owner
 */
contract FloorERC1155PricingModule is PricingModule {
    struct AssetInformation {
        uint256 id;
        address assetAddress;
        address[] oracleAddresses;
    }

    mapping(address => AssetInformation) public assetToInformation;

    /**
     * @notice A Pricing Logic must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry The address of the Main-registry
     * @param oracleHub The address of the Oracle-Hub
     */
    constructor(address mainRegistry, address oracleHub) PricingModule(mainRegistry, oracleHub) {}

    /**
     * @notice Adds a new asset to the FloorERC1155PricingModule, or overwrites an existing one.
     * @param assetInformation A Struct with information about the asset
     * - id: The Id of the asset
     * - assetAddress: The contract address of the asset
     * - oracleAddresses: An array of addresses of oracle contracts, to price the asset in USD
     * @param assetCreditRatings The List of Credit Ratings for the asset for the different BaseCurrencies.
     * @dev The list of Credit Ratings should or be as long as the number of baseCurrencies added to the Main Registry,
     * or the list must have length 0. If the list has length zero, the credit ratings of the asset for all baseCurrencies is
     * is initiated as credit rating with index 0 by default (worst credit rating).
     * @dev The assets are added/overwritten in the Main-Registry as well.
     * By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     * (for instance by changing the oracleaddres to a fake price feed) and poses a security risk towards protocol users.
     * This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     * assets are no longer updatable.
     */
    function setAssetInformation(AssetInformation calldata assetInformation, uint256[] calldata assetCreditRatings)
        external
        onlyOwner
    {
        IOraclesHub(oracleHub).checkOracleSequence(assetInformation.oracleAddresses);

        address assetAddress = assetInformation.assetAddress;
        if (!inPricingModule[assetAddress]) {
            inPricingModule[assetAddress] = true;
            assetsInPricingModule.push(assetAddress);
        }
        assetToInformation[assetAddress] = assetInformation;
        isAssetAddressWhiteListed[assetAddress] = true;
        IMainRegistry(mainRegistry).addAsset(assetAddress, assetCreditRatings);
    }

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

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     * - assetAddress: The contract address of the asset
     * - assetId: The Id of the asset
     * - assetAmount: The Amount of tokens
     * - baseCurrency: The BaseCurrency (base-asset) in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInBaseCurrency The value of the asset denominated in BaseCurrency different from USD with 18 Decimals precision
     * @dev If the Oracle-Hub returns the rate in a baseCurrency different from USD, the StandardERC20Registry will return
     * the value of the asset in the same BaseCurrency. If the Oracle-Hub returns the rate in USD, the StandardERC20Registry
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
        returns (uint256 valueInUsd, uint256 valueInBaseCurrency)
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
    }
}
