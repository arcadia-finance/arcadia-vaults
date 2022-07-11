/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractSubRegistry.sol";

/**
 * @title Sub-registry for ERC721 tokens for which a oracle exists for the floor price of the collection
 * @author Arcadia Finance
 * @notice The FloorERC721SubRegistry stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
 *         for the floor price of the collection
 * @dev No end-user should directly interact with the FloorERC721SubRegistry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract FloorERC721SubRegistry is SubRegistry {
    struct AssetInformation {
        uint256 idRangeStart;
        uint256 idRangeEnd;
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
     * @notice Adds a new asset to the FloorERC721SubRegistry, or overwrites an existing asset.
     * @param assetInformation A Struct with information about the asset
     *                         - idRangeStart: The id of the first NFT of the collection
     *                         - idRangeEnd: The id of the last NFT of the collection
     *                         - assetAddress: The contract address of the asset
     *                         - oracleAddresses: An array of addresses of oracle contracts, to price the asset in USD
     * @param assetCreditRatings The List of Credit Ratings for the asset for the different Numeraires
     * @dev The list of Credit Ratings should or be as long as the number of numeraires added to the Main Registry,
     *      or the list must have length 0. If the list has length zero, the credit ratings of the asset for all numeraires is
     *      is initiated as credit rating with index 0 by default (worst credit rating)
     * @dev The assets are added/overwritten in the Main-Registry as well.
     *      By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     *      (for instance by changing the oracleaddres to a fake price feed) and poses a security risk towards protocol users.
     *      This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     *      assets are no longer updatable.
     */
    function setAssetInformation(
        AssetInformation calldata assetInformation,
        uint256[] calldata assetCreditRatings
    ) external onlyOwner {
        IOraclesHub(oracleHub).checkOracleSequence(
            assetInformation.oracleAddresses
        );

        address assetAddress = assetInformation.assetAddress;
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
     * @return idRangeStart The id of the first token of the collection
     * @return idRangeEnd The id of the last token of the collection
     * @return assetAddress The contract address of the asset
     * @return oracleAddresses The list of addresses of the oracles to get the exchange rate of the asset in USD
     */
    function getAssetInformation(address asset)
        external
        view
        returns (
            uint256,
            uint256,
            address,
            address[] memory
        )
    {
        return (
            assetToInformation[asset].idRangeStart,
            assetToInformation[asset].idRangeEnd,
            assetToInformation[asset].assetAddress,
            assetToInformation[asset].oracleAddresses
        );
    }

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param assetAddress The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the asset passed as input is whitelisted
     */
    function isWhiteListed(address assetAddress, uint256 assetId)
        external
        view
        override
        returns (bool)
    {
        if (isAssetAddressWhiteListed[assetAddress]) {
            if (isIdInRange(assetAddress, assetId)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Checks if the Id for a given token is in the range for which there exists a price feed
     * @param assetAddress The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the Id of the given asset is whitelisted
     */
    function isIdInRange(address assetAddress, uint256 assetId)
        private
        view
        returns (bool)
    {
        if (
            assetId >= assetToInformation[assetAddress].idRangeStart &&
            assetId <= assetToInformation[assetAddress].idRangeEnd
        ) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another Numeraire
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     *                      - assetAddress: The contract address of the asset
     *                      - assetId: The Id of the asset
     *                      - assetAmount: Since ERC721 tokens have no amount, the amount should be set to 0
     *                      - numeraire: The Numeraire (base-asset) in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInNumeraire The value of the asset denominated in Numeraire different from USD with 18 Decimals precision
     * @dev If the Oracle-Hub returns the rate in a numeraire different from USD, the StandardERC20Registry will return
     *      the value of the asset in the same Numeraire. If the Oracle-Hub returns the rate in USD, the StandardERC20Registry
     *      will return the value of the asset in USD.
     *      Only one of the two values can be different from 0.
     * @dev If the asset is not first added to subregistry this function will return value 0 without throwing an error.
     *      However no check in FloorERC721SubRegistry is necessary, since the check if the asset is whitelisted (and hence added to subregistry)
     *      is already done in the Main-Registry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 valueInNumeraire)
    {
        (valueInUsd, valueInNumeraire) = IOraclesHub(oracleHub).getRate(
            assetToInformation[getValueInput.assetAddress].oracleAddresses,
            getValueInput.numeraire
        );
    }
}
