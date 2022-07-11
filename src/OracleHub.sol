/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IChainLinkData.sol";

import {Printing} from "./utils/Printer.sol";
import {FixedPointMathLib} from "./utils/FixedPointMathLib.sol";

/**
 * @title Oracle Hub
 * @author Arcadia Finance
 * @notice The Oracle Hub stores the adressesses and other necessary information of the Price Oracles and returns rates of assets
 * @dev No end-user should directly interact with the Oracle-Hub, only the Main Registry, Sub-Registries or the contract owner.
 *     Current integration is only for mocked Chainlink oracles, and we assume the oracles are honest
 *     and functioning properly, no unhappy flows are implemented yet
 *     (oracle stops updating, circuit brakers activated...).
 *     ToDo: implement sanety checks + unhappy flows
 */
contract OracleHub is Ownable {
    using FixedPointMathLib for uint256;

    struct OracleInformation {
        uint64 oracleUnit;
        uint8 baseAssetNumeraire;
        bool baseAssetIsNumeraire;
        string quoteAsset;
        string baseAsset;
        address oracleAddress;
        address quoteAssetAddress;
    }

    mapping(address => bool) public inOracleHub;
    mapping(address => OracleInformation) public oracleToOracleInformation;

    /**
     * @notice Constructor
     */
    constructor() {}

    /**
     * @notice Add a new oracle to the Oracle Hub
     * @param oracleInformation A Struct with information about the Oracle:
     *    - oracleUnit: the unit of the oracle, equal to 10 to the power of the number of decimals of the oracle
     *    - baseAssetNumeraire: a unique identifier if the base asset can be used as numeraire of a vault,
     *      0 by default if the base asset cannot be used as numeraire
     *    - baseAssetIsNumeraire: boolean indicating if the base asset can be used as numeraire of a vault
     *    - quoteAsset: The symbol of the quote assets (only used for readability purpose)
     *    - baseAsset: The symbol of the base assets (only used for readability purpose)
     *    - oracleAddress: The contract address of the oracle
     *    - quoteAssetAddress: The contract address of the quote asset
     * @dev It is not possible to overwrite the information of an existing Oracle in the Oracle Hub.
     * @dev Oracles can't have more than 18 decimals.
     */
    function addOracle(OracleInformation calldata oracleInformation)
        external
        onlyOwner
    {
        address oracleAddress = oracleInformation.oracleAddress;
        require(!inOracleHub[oracleAddress], "Oracle already in oracle-hub");
        require(
            oracleInformation.oracleUnit <= 1000000000000000000,
            "Oracle can have maximal 18 decimals"
        );
        inOracleHub[oracleAddress] = true;
        oracleToOracleInformation[oracleAddress] = oracleInformation;
    }

    /**
     * @notice Checks if two input strings are identical, if so returns true
     * @param a The first string to be compared
     * @param b The second string to be compared
     * @return result Boolean that returns true if both input strings are equal, and false if both strings are different
     */
    function compareStrings(string memory a, string memory b)
        internal
        pure
        returns (bool result)
    {
        if (bytes(a).length != bytes(b).length) {
            return false;
        } else {
            result = keccak256(bytes(a)) == keccak256(bytes(b));
        }
    }

    /**
     * @notice Checks if a series of oracles adheres to a predefined ruleset
     * @param oracleAdresses An array of addresses of oracle contracts
     * @dev Function will do nothing if all checks pass, but reverts if at least one check fails.
     *      The following checks are performed:
     *      - The oracle-address must be previously added to the Oracle-Hub.
     *      - The last oracle in the series must have USD as base-asset.
     *      - The Base-asset of all oracles must be equal to the quote-asset of the next oracle (except for the last oracle in the series).
     */
    function checkOracleSequence(address[] memory oracleAdresses)
        external
        view
    {
        uint256 oracleAdressesLength = oracleAdresses.length;
        require(oracleAdressesLength <= 3, "Oracle seq. cant be longer than 3");
        for (uint256 i; i < oracleAdressesLength; ) {
            require(inOracleHub[oracleAdresses[i]], "Unknown oracle");
            if (i > 0) {
                require(
                    compareStrings(
                        oracleToOracleInformation[oracleAdresses[i - 1]]
                            .baseAsset,
                        oracleToOracleInformation[oracleAdresses[i]].quoteAsset
                    ),
                    "qAsset doesnt match with bAsset of prev oracle"
                );
            }
            if (i == oracleAdressesLength - 1) {
                require(
                    compareStrings(
                        oracleToOracleInformation[oracleAdresses[i]].baseAsset,
                        "USD"
                    ),
                    "Last oracle does not have USD as bAsset"
                );
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Returns the exchange rate of a certain asset, denominated in USD or in another Numeraire
     * @param oracleAdresses An array of addresses of oracle contracts
     * @param numeraire The Numeraire (base-asset) in which the exchange rate is ideally expressed
     * @return rateInUsd The exchange rate of the asset denominated in USD, integer with 18 Decimals precision
     * @return rateInNumeraire The exchange rate of the asset denominated in a Numeraire different from USD, integer with 18 Decimals precision
     * @dev The Function will loop over all oracles-addresses and find the total exchange rate of the asset by
     *      multiplying the intermediate exchangerates (max 3) with eachother. Oracles can have any Decimals precision smaller than 18.
     *      All intermediate exchange rates are calculated with a precision of 18 decimals and rounded down.
     *      Todo: check precision when multiplying multiple small rates -> go to 27 decimals precision??
     *      Function will overflow if any of the intermediate or the final exchange rate overflows
     *      Example of 3 oracles with R1 the first exchange rate with D1 decimals and R2 the second exchange rate with D2 decimals R3...
     *       - First intermediate rate will overflow when R1 * 10**18 > MAXUINT256
     *       - Second rate will overflow when R1 * R2 * 10**(18 - D1) > MAXUINT256
     *       - Third and final exchange rate will overflow when R1 * R2 * R3 * 10**(18 - D1 - D2) > MAXUINT256
     * @dev The exchange rate of an asset will be denominated in a numeraire different from USD if and only if
     *      the given numeraire is different from USD (numeraire is not 0) and one of the intermediate oracles to price the asset has
     *      the given numeraire as base-asset.
     *      The exchange rate of an asset will be denominated in USD if the numeraire is USD (numeraire equals 0) or
     *      the given numeraire is different from USD (numeraire is not 0) but none of the oracles to price the asset has
     *      the given numeraire as base-asset.
     *      Only one of the two values can be different from 0.
     */
    function getRate(address[] memory oracleAdresses, uint256 numeraire)
        public
        view
        returns (uint256 rateInUsd, uint256 rateInNumeraire)
    {
        //Scalar 1 with 18 decimals (internal precision for)
        uint256 rate = FixedPointMathLib.WAD;
        int256 tempRate;
        uint256 oraclesLength = oracleAdresses.length;
        address oracleAddressAtIndex;

        for (uint256 i; i < oraclesLength; ) {
            oracleAddressAtIndex = oracleAdresses[i];
            (, tempRate, , , ) = IChainLinkData(oracleAddressAtIndex)
                .latestRoundData();
            require(tempRate >= 0, "Negative oracle price");

            rate = rate.mulDivDown(
                uint256(tempRate),
                oracleToOracleInformation[oracleAddressAtIndex].oracleUnit
            );

            if (
                oracleToOracleInformation[oracleAddressAtIndex]
                    .baseAssetIsNumeraire
            ) {
                if (
                    oracleToOracleInformation[oracleAddressAtIndex]
                        .baseAssetNumeraire == 0
                ) {
                    //If rate is expressed in USD, return rate expressed in USD
                    rateInUsd = rate;
                    return (rateInUsd, rateInNumeraire);
                } else if (
                    oracleToOracleInformation[oracleAddressAtIndex]
                        .baseAssetNumeraire == numeraire
                ) {
                    //If rate is expressed in numeraire, return rate expressed in numeraire
                    rateInNumeraire = rate;
                    return (rateInUsd, rateInNumeraire);
                }
            }

            unchecked {
                ++i;
            }
        }
        //Since all series of oracles must end with USD, it should be impossible to arrive at this point
        revert("No oracle with USD or numeraire as bAsset");
    }
}
