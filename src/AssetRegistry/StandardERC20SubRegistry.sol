/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractSubRegistry.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

/**
 * @title Sub-registry for Standard ERC20 tokens
 * @author Arcadia Finance
 * @notice The StandardERC20Registry stores pricing logic and basic information for ERC20 tokens for which a direct price feed exists
 * @dev No end-user should directly interact with the StandardERC20Registry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract StandardERC20Registry is SubRegistry {
    using FixedPointMathLib for uint256;

    struct AssetInformation {
        uint64 assetUnit;
        address assetAddress;
        address[] oracleAddresses;
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
     * @notice Adds a new asset to the StandardERC20Registry, or overwrites an existing asset.
     * @param assetInformation A Struct with information about the asset
     *                         - assetUnit: The unit of the asset, equal to 10 to the power of the number of decimals of the asset
     *                         - assetAddress: The contract address of the asset
     *                         - oracleAddresses: An array of addresses of oracle contracts, to price the asset in USD
     * @param assetCreditRatings The List of Credit Ratings for the asset for the different Numeraires.
     * @dev The list of Credit Ratings should or be as long as the number of numeraires added to the Main Registry,
     *      or the list must have length 0. If the list has length zero, the credit ratings of the asset for all numeraires is
     *      is initiated as credit rating with index 0 by default (worst credit rating).
     * @dev The assets are added/overwritten in the Main-Registry as well.
     *      By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     *      (for instance by changing the oracleaddres to a fake price feed) and poses a security risk towards protocol users.
     *      This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     *      assets are no longer updatable.
     * @dev Assets can't have more than 18 decimals.
     */
    function setAssetInformation(
        AssetInformation calldata assetInformation,
        uint256[] calldata assetCreditRatings
    ) external onlyOwner {
        IOraclesHub(oracleHub).checkOracleSequence(
            assetInformation.oracleAddresses
        );

        address assetAddress = assetInformation.assetAddress;
        require(
            assetInformation.assetUnit <= 1000000000000000000,
            "SSR_SAI: Maximal 18 decimals"
        );
        if (!inSubRegistry[assetAddress]) {
            inSubRegistry[assetAddress] = true;
            assetsInSubRegistry.push(assetAddress);
        }
        assetToInformation[assetAddress] = assetInformation;
        isAssetAddressWhiteListed[assetAddress] = true;
        IMainRegistry(mainRegistry).addAsset(assetAddress, assetCreditRatings);
    }

    /**
     * @notice Returns the information that is stored in the Sub-registry for a given asset
     * @dev struct is not taken into memory; saves 6613 gas
     * @param asset The Token address of the asset
     * @return assetDecimals The number of decimals of the asset
     * @return assetAddress The Token address of the asset
     * @return oracleAddresses The list of addresses of the oracles to get the exchange rate of the asset in USD
     */
    function getAssetInformation(address asset)
        external
        view
        returns (
            uint64,
            address,
            address[] memory
        )
    {
        return (
            assetToInformation[asset].assetUnit,
            assetToInformation[asset].assetAddress,
            assetToInformation[asset].oracleAddresses
        );
    }

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param assetAddress The address of the asset
     * @dev Since ERC20 tokens have no Id, the Id should be set to 0
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
     * @notice Returns the value of a certain asset, denominated in USD or in another Numeraire
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     *                      - assetAddress: The contract address of the asset
     *                      - assetId: Since ERC20 tokens have no Id, the Id should be set to 0
     *                      - assetAmount: The Amount of tokens, ERC20 tokens can have any Decimals precision smaller than 18.
     *                      - numeraire: The Numeraire (base-asset) in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInNumeraire The value of the asset denominated in Numeraire different from USD with 18 Decimals precision
     * @dev If the Oracle-Hub returns the rate in a numeraire different from USD, the StandardERC20Registry will return
     *      the value of the asset in the same Numeraire. If the Oracle-Hub returns the rate in USD, the StandardERC20Registry
     *      will return the value of the asset in USD.
     *      Only one of the two values can be different from 0.
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
     * @dev If the asset is not first added to subregistry this function will return value 0 without throwing an error.
     *      However no check in StandardERC20Registry is necessary, since the check if the asset is whitelisted (and hence added to subregistry)
     *      is already done in the Main-Registry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 valueInNumeraire)
    {
        uint256 rateInUsd;
        uint256 rateInNumeraire;

        (rateInUsd, rateInNumeraire) = IOraclesHub(oracleHub).getRate(
            assetToInformation[getValueInput.assetAddress].oracleAddresses,
            getValueInput.numeraire
        );

        if (rateInNumeraire > 0) {
            valueInNumeraire = (getValueInput.assetAmount).mulDivDown(
                rateInNumeraire,
                assetToInformation[getValueInput.assetAddress].assetUnit
            );
        } else {
            valueInUsd = (getValueInput.assetAmount).mulDivDown(
                rateInUsd,
                assetToInformation[getValueInput.assetAddress].assetUnit
            );
        }
    }
}
