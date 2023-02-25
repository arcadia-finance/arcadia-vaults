/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { IChainLinkData } from "./interfaces/IChainLinkData.sol";
import { IOraclesHub } from "./PricingModules/interfaces/IOraclesHub.sol";
import { StringHelpers } from "./utils/StringHelpers.sol";
import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Owned } from "lib/solmate/src/auth/Owned.sol";

/**
 * @title Oracle Hub
 * @author Arcadia Finance
 * @notice The Oracle Hub stores the addresses and other necessary information of the Price Oracles and returns rates of assets
 * @dev No end-user should directly interact with the Oracle-Hub, only the Main Registry, Sub-Registries or the contract owner.
 */
contract OracleHub is Owned, IOraclesHub {
    using FixedPointMathLib for uint256;

    mapping(address => bool) public inOracleHub;
    mapping(address => OracleInformation) public oracleToOracleInformation;

    struct OracleInformation {
        bool isActive;
        uint64 oracleUnit;
        uint8 baseAssetBaseCurrency;
        bool baseAssetIsBaseCurrency;
        address oracle;
        address quoteAssetAddress;
        bytes16 quoteAsset;
        bytes16 baseAsset;
    }

    /**
     * @notice Constructor
     */
    constructor() Owned(msg.sender) { }

    /*///////////////////////////////////////////////////////////////
                          ORACLE MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new oracle to the Oracle Hub
     * @param oracleInformation A Struct with information about the Oracle:
     * - isActive: Boolean indicating if the oracle is active or decommissioned (and returns value 0)
     * - oracleUnit: the unit of the oracle, equal to 10 to the power of the number of decimals of the oracle
     * - baseAssetBaseCurrency: a unique identifier if the base asset can be used as baseCurrency of a vault,
     * 0 by default if the base asset cannot be used as baseCurrency
     * - baseAssetIsBaseCurrency: boolean indicating if the base asset can be used as baseCurrency of a vault
     * - oracle: The contract address of the oracle
     * - quoteAssetAddress: The contract address of the quote asset
     * - quoteAsset: The symbol of the quote assets (only used for readability purpose)
     * - baseAsset: The symbol of the base assets (only used for readability purpose)
     * @dev It is not possible to overwrite the information of an existing Oracle in the Oracle Hub.
     * @dev Oracles can't have more than 18 decimals.
     */
    function addOracle(OracleInformation calldata oracleInformation) external onlyOwner {
        address oracle = oracleInformation.oracle;
        require(!inOracleHub[oracle], "OH_AO: Oracle not unique");
        require(oracleInformation.oracleUnit <= 1_000_000_000_000_000_000, "OH_AO: Maximal 18 decimals");
        inOracleHub[oracle] = true;
        oracleToOracleInformation[oracle] = oracleInformation;
    }

    /**
     * @notice Checks if a series of oracles adheres to a predefined ruleset
     * @param oracles An array of addresses of oracle contracts
     * @dev Function will do nothing if all checks pass, but reverts if at least one check fails.
     * The following checks are performed:
     * - The oracle-address must be previously added to the Oracle-Hub.
     * - The last oracle in the series must have USD as base-asset.
     * - The Base-asset of all oracles must be equal to the quote-asset of the next oracle (except for the last oracle in the series).
     */
    function checkOracleSequence(address[] calldata oracles) external view {
        uint256 oracleAdressesLength = oracles.length;
        require(oracleAdressesLength <= 3, "OH_COS: Max 3 Oracles");
        address oracle;
        for (uint256 i; i < oracleAdressesLength;) {
            oracle = oracles[i];
            require(inOracleHub[oracle], "OH_COS: Unknown Oracle");
            if (i > 0) {
                require(
                    oracleToOracleInformation[oracles[i - 1]].baseAsset == oracleToOracleInformation[oracle].quoteAsset,
                    "OH_COS: No Match qAsset and bAsset"
                );
            }
            if (i == oracleAdressesLength - 1) {
                require(oracleToOracleInformation[oracle].baseAsset == "USD", "OH_COS: Last bAsset not USD");
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Sets an oracle to inactive if it has not been updated in the last week or if its answer is below the minimum answer.
     * @param oracle The address of the oracle to be checked
     * @dev An inactive oracle will always return a rate of 0.
     * @dev Anyone can call this function as part of an oracle failsafe mechanism.
     * Next to the deposit limits, the rate of an asset can be set to 0 if the oracle is not performing as intended.
     * @dev If the oracle would becomes functionally again (all checks pass), anyone can activate the oracle again.
     */
    function decommissionOracle(address oracle) external returns (bool) {
        require(inOracleHub[oracle], "OH_DO: Oracle not in Hub");

        bool oracleIsInUse = true;

        try IChainLinkData(oracle).latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
        {
            int192 min = IChainLinkData(IChainLinkData(oracle).aggregator()).minAnswer();
            if (answer <= min) {
                oracleIsInUse = false;
            } else if (updatedAt <= block.timestamp - 1 weeks) {
                oracleIsInUse = false;
            }
        } catch {
            oracleIsInUse = false;
        }

        oracleToOracleInformation[oracle].isActive = oracleIsInUse;

        return oracleIsInUse;
    }

    /**
     * @notice Returns the state of an oracle
     * @param oracle The address of the oracle to be checked
     * @return boolean indicationg if the oracle is active or not
     */
    function isActive(address oracle) external view returns (bool) {
        return oracleToOracleInformation[oracle].isActive;
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the rate of a certain asset, denominated in USD or in another BaseCurrency
     * @param oracles An array of addresses of oracle contracts
     * @param baseCurrency The BaseCurrency (base-asset) in which the rate is ideally expressed
     * @return rateInUsd The rate of the asset denominated in USD, integer with 18 Decimals precision
     * @return rateInBaseCurrency The rate of the asset denominated in a BaseCurrency different from USD, integer with 18 Decimals precision
     * @dev The Function will loop over all oracles-addresses and find the total rate of the asset by
     * multiplying the intermediate exchangerates (max 3) with eachother. Oracles can have any Decimals precision smaller than 18.
     * All intermediate rates are calculated with a precision of 18 decimals and rounded down.
     * Function will overflow if any of the intermediate or the final rate overflows
     * Example of 3 oracles with R1 the first rate with D1 decimals and R2 the second rate with D2 decimals R3...
     * - First intermediate rate will overflow when R1 * 10**18 > MAXUINT256
     * - Second rate will overflow when R1 * R2 * 10**(18 - D1) > MAXUINT256
     * - Third and final rate will overflow when R1 * R2 * R3 * 10**(18 - D1 - D2) > MAXUINT256
     * @dev The rate of an asset will be denominated in a baseCurrency different from USD if and only if
     * the given baseCurrency is different from USD (baseCurrency is not 0) and one of the intermediate oracles to price the asset has
     * the given baseCurrency as base-asset.
     * The rate of an asset will be denominated in USD if the baseCurrency is USD (baseCurrency equals 0) or
     * the given baseCurrency is different from USD (baseCurrency is not 0) but none of the oracles to price the asset has
     * the given baseCurrency as base-asset.
     * Only one of the two values can be different from 0.
     */
    function getRate(address[] memory oracles, uint256 baseCurrency)
        external
        view
        returns (uint256 rateInUsd, uint256 rateInBaseCurrency)
    {
        //Scalar 1 with 18 decimals (internal precision for)
        uint256 rate = FixedPointMathLib.WAD; //All rates for internal calculations have 18 decimals precision
        int256 tempRate;
        uint256 oraclesLength = oracles.length;
        address oracleAddressAtIndex;

        for (uint256 i; i < oraclesLength;) {
            oracleAddressAtIndex = oracles[i];

            //If the oracle is not active anymore (decomissioned), return value 0 -> assets do not count as collateral anymore
            if (!oracleToOracleInformation[oracleAddressAtIndex].isActive) return (0, 0);

            (, tempRate,,,) = IChainLinkData(oracleAddressAtIndex).latestRoundData();
            require(tempRate >= 0, "OH_GR: Negative Rate");

            rate = rate.mulDivDown(uint256(tempRate), oracleToOracleInformation[oracleAddressAtIndex].oracleUnit);

            if (oracleToOracleInformation[oracleAddressAtIndex].baseAssetIsBaseCurrency) {
                if (oracleToOracleInformation[oracleAddressAtIndex].baseAssetBaseCurrency == 0) {
                    //If rate is expressed in USD, return rate expressed in USD
                    return (rate, 0);
                } else if (oracleToOracleInformation[oracleAddressAtIndex].baseAssetBaseCurrency == baseCurrency) {
                    //If rate is expressed in baseCurrency, return rate expressed in baseCurrency
                    return (0, rate);
                }
            }

            unchecked {
                ++i;
            }
        }
        //Since all series of oracles must end with USD, it should be impossible to arrive at this point
        revert("OH_GR: No bAsset in USD or bCurr");
    }
}
