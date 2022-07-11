/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {FixedPointMathLib} from "./utils/FixedPointMathLib.sol";

/**
 * @title Interest Rate Module
 * @author Arcadia Finance
 * @notice The Interest Rate Module manages the base interest rate and the collateral specific interest rates
 * @dev No end-user should directly interact with the Interest Rate Module, only the Main-registry or the contract owner
 */
contract InterestRateModule is Ownable {
    using FixedPointMathLib for uint256;
    uint256 public baseInterestRate;

    mapping(uint256 => uint256) public creditRatingToInterestRate;

    /**
     * @notice Constructor
     */
    constructor() {}

    /**
     * @notice Sets the base interest rate (cost of capital)
     * @param _baseInterestRate The new base interest rate (yearly APY)
     * @dev The base interest rate is standard initialized as 0
     *      the base interest rate is the relative compounded interest after one year, it is an integer with 18 decimals
     *      Example: For a yearly base interest rate of 2% APY, _baseInterestRate must equal 20 000 000 000 000 000
     */
    function setBaseInterestRate(uint64 _baseInterestRate) external onlyOwner {
        baseInterestRate = _baseInterestRate;
    }

    /**
     * @notice Sets interest rate for Credit Rating Categories (risks associated with collateral)
     * @param creditRatings The list of indices of the Credit Rating Categories for which the Interest Rate needs to be changed
     * @param interestRates The list of new interest rates (yearly APY) for the corresponding Credit Rating Categories
     * @dev The Credit Rating Categories are standard initialized with 0
     * @dev The interest rates are relative compounded interests after one year, it are integers with 18 decimals
     *      Example: For a yearly interest rate of 2% APY, the interest must equal 20 000 000 000 000 000
     * @dev Each Credit Rating Category is labeled with an integer, Category 0 (the default) is for the most risky assets
     *      hence it will have the highest interest rate. Each Category from 1 to 9 will be used to label groups of assets
     *      with similar risk profiles (Comparable to ratings like AAA, A-, B... for debtors in traditional finance).
     */
    function batchSetCollateralInterestRates(
        uint256[] calldata creditRatings,
        uint256[] calldata interestRates
    ) external onlyOwner {
        uint256 creditRatingsLength = creditRatings.length;
        require(
            creditRatingsLength == interestRates.length,
            "IRM: LENGTH_MISMATCH"
        );
        for (uint256 i; i < creditRatingsLength; ) {
            creditRatingToInterestRate[creditRatings[i]] = interestRates[i];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Returns the weighted interest rate of a basket of different assets depending on their Credit rating category
     * @param valuesPerCreditRating A list of the values (denominated in a single Numeraire) of assets per Credit Rating Category
     * @param minCollValue The minimal collaterisation value (denominated in the same Numeraire)
     * @return collateralInterestRate The weighted asset specific interest rate of a basket of assets
     * @dev Since each Credit Rating Category has its own specific interest rate, the interest rate for a basket of collateral
     *      is calculated as the weighted interest rate over the different Credit Rating Categories.
     *      The function will start from the highest quality Credit Rating Category (labeled as 1) check if the value of Category 1 exceeds
     *      a certain treshhold, the minimal collaterisation value. If not it goes to the second best category(labeled as 2) and so forth.
     *      If the treshhold is not reached after category 9, the remainder of value to meet the minimal collaterisation value is
     *      assumed to be of the worst category (labeled as 0).
     */
    function calculateWeightedCollateralInterestrate(
        uint256[] memory valuesPerCreditRating,
        uint256 minCollValue
    ) internal view returns (uint256) {
        if (minCollValue == 0) {
            return 0;
        } else {
            uint256 collateralInterestRate;
            uint256 totalValue;
            uint256 value;
            uint256 valuesPerCreditRatingLength = valuesPerCreditRating.length;
            //Start from Category 1 (highest quality assets)
            for (uint256 i = 1; i < valuesPerCreditRatingLength; ) {
                value = valuesPerCreditRating[i];
                if (totalValue + value < minCollValue) {
                    collateralInterestRate += creditRatingToInterestRate[i]
                        .mulDivDown(value, minCollValue);
                    totalValue += value;
                } else {
                    value = minCollValue - totalValue;
                    collateralInterestRate += creditRatingToInterestRate[i]
                        .mulDivDown(value, minCollValue);
                    return collateralInterestRate;
                }
                unchecked {
                    ++i;
                }
            }
            //Loop ended without returning -> use lowest credit rating (at index 0) for remaining collateral
            value = minCollValue - totalValue;
            collateralInterestRate += creditRatingToInterestRate[0].mulDivDown(
                value,
                minCollValue
            );

            return collateralInterestRate;
        }
    }

    /**
     * @notice Returns the interest rate of a basket of different assets
     * @param valuesPerCreditRating A list of the values (denominated in a single Numeraire) of assets per Credit Rating Category
     * @param minCollValue The minimal collaterisation value (denominated in the same Numeraire)
     * @return yearlyInterestRate The total yearly compounded interest rate of of a basket of assets
     * @dev The yearly interest rate exists out of a base rate (cost of capital) and a collatereal specific rate (price risks of collateral)
     *      The interest rate is the relative compounded interest after one year, it is an integer with 18 decimals
     *      Example: For a yearly interest rate of 2% APY, yearlyInterestRate will equal 20 000 000 000 000 000
     */
    function getYearlyInterestRate(
        uint256[] calldata valuesPerCreditRating,
        uint256 minCollValue
    ) external view returns (uint64 yearlyInterestRate) {
        //ToDo: checks on min and max length to implement
        yearlyInterestRate =
            uint64(baseInterestRate) +
            uint64(
                calculateWeightedCollateralInterestrate(
                    valuesPerCreditRating,
                    minCollValue
                )
            );
    }
}
