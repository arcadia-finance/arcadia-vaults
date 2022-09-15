/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractSubRegistry.sol";
import "../interfaces/IERC4626.sol";
import "../interfaces/ISubRegistry.sol";
import "../interfaces/IMainRegistry.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

/**
 * @title Sub-registry for Standard ERC4626 tokens
 * @author Arcadia Finance
 * @notice The StandardERC4626Registry stores pricing logic and basic information for ERC4626 tokens for which the underlying assets have direct price feed.
 * @dev No end-user should directly interact with the StandardERC4626Registry, only the Main-registry, Oracle-Hub or the contract owner */
contract StandardERC4626SubRegistry is SubRegistry {
    using FixedPointMathLib for uint256;

    struct AssetInformation {
        uint64 assetUnit;
        address assetAddress;
        address underlyingAssetAddress;
        address[] underlyingAssetOracleAddresses;
    }

    mapping(address => AssetInformation) public assetToInformation;

    /**
     * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry The address of the Main-registry
     * @param oracleHub The address of the Oracle-Hub
     */
    constructor(address mainRegistry, address oracleHub)
        SubRegistry(mainRegistry, oracleHub)
    {}

    /**
     * @notice Adds a new asset to the ATokenSubRegistry, or overwrites an existing asset.
     * @param assetAddress The contract address of the asset
     * @param assetCreditRatings The List of Credit Ratings for the asset for the different BaseCurrencies.
     * @dev The list of Credit Ratings should or be as long as the number of baseCurrencies added to the Main Registry,
     *      or the list must have length 0. If the list has length zero, the credit ratings of the asset for all baseCurrencies is
     *      is initiated as credit rating with index 0 by default (worst credit rating).
     * @dev The assets are added/overwritten in the Main-Registry as well.
     *      By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     *      (for instance by changing the oracleaddres to a fake price feed) and poses a security risk towards protocol users.
     *      This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     *      assets are no longer updatable.
     * @dev Assets can't have more than 18 decimals.
     */
    function setAssetInformation(
        address assetAddress,
        uint256[] calldata assetCreditRatings
    ) external onlyOwner {
        address underlyingAddress = address(IERC4626(assetAddress).asset());
        (
            uint64 assetUnit,
            address underlyingAssetAddress,
            address[] memory underlyingAssetOracleAddresses
            ) = ISubRegistry(IMainRegistry(mainRegistry).assetToSubRegistry(underlyingAddress)).getAssetInformation(underlyingAddress);

        require(10 ** IERC4626(assetAddress).decimals() == assetUnit, "SR: Decimals of asset and underlying don't match");

        address[] memory tokens = new address[](1);
        tokens[0] = underlyingAssetAddress;

        if (!inSubRegistry[assetAddress]) {
            inSubRegistry[assetAddress] = true;
            assetsInSubRegistry.push(assetAddress);
        }
        assetToInformation[assetAddress].assetAddress = assetAddress;
        assetToInformation[assetAddress].assetUnit = assetUnit;
        assetToInformation[assetAddress].underlyingAssetAddress = underlyingAssetAddress;
        assetToInformation[assetAddress].underlyingAssetOracleAddresses = underlyingAssetOracleAddresses;
        isAssetAddressWhiteListed[assetAddress] = true;
        IMainRegistry(mainRegistry).addAsset(assetAddress, assetCreditRatings);
    }

    /**
     * @notice Returns the information that is stored in the Sub-registry for a given asset
     * @dev struct is not taken into memory; saves 6613 gas
     * @param asset The Token address of the asset
     * @return assetDecimals The number of decimals of the asset
     * @return assetAddress The Token address of the asset
     * @return underlyingAssetAddress The Token address of the underlying asset
     * @return underlyingAssetOracleAddresses The list of addresses of the oracles to get the exchange rate of the underlying asset in USD
     */
    function getAssetInformation(address asset)
        external
        view
        returns (
            uint64,
            address,
            address,
            address[] memory
        )
    {
        return (
            assetToInformation[asset].assetUnit,
            assetToInformation[asset].assetAddress,
            assetToInformation[asset].underlyingAssetAddress,
            assetToInformation[asset].underlyingAssetOracleAddresses
        );
    }

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param assetAddress The address of the asset
     * @dev Since ERC4626 tokens have no Id, the Id should be set to 0
     * @return A boolean, indicating if the asset passed as input is whitelisted
     */
    function isWhiteListed(address assetAddress, uint256)
        external
        view
        override
        returns (bool)
    {
        if (isAssetAddressWhiteListed[assetAddress]) {
            return true;
        }

        return false;
    }

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     *                      - assetAddress: The contract address of the asset
     *                      - assetId: Since ERC4626 tokens have no Id, the Id should be set to 0
     *                      - assetAmount: The Amount of Shares, ERC4626 tokens can have any Decimals precision smaller than 18.
     *                      - baseCurrency: The BaseCurrency (base-asset) in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInBaseCurrency The value of the asset denominated in BaseCurrency different from USD with 18 Decimals precision
     * @dev If the Oracle-Hub returns the rate in a baseCurrency different from USD, the StandardERC4626Registry will return
     *      the value of the asset in the same BaseCurrency. If the Oracle-Hub returns the rate in USD, the StandardERC4626Registry
     *      will return the value of the asset in USD.
     *      Only one of the two values can be different from 0.
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
     * @dev If the asset is not first added to subregistry this function will return value 0 without throwing an error.
     *      However no check in StandardERC4626Registry is necessary, since the check if the asset is whitelisted (and hence added to subregistry)
     *      is already done in the Main-Registry.
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
            assetToInformation[getValueInput.assetAddress].underlyingAssetOracleAddresses,
            getValueInput.baseCurrency
        );

        uint256 assetAmount = IERC4626(getValueInput.assetAddress).convertToAssets(getValueInput.assetAmount);
        if (rateInBaseCurrency > 0) {
            valueInBaseCurrency = assetAmount.mulDivDown(
                rateInBaseCurrency,
                assetToInformation[getValueInput.assetAddress].assetUnit
            );
        } else {
            valueInUsd = assetAmount.mulDivDown(
                rateInUsd,
                assetToInformation[getValueInput.assetAddress].assetUnit
            );
        }
    }
}