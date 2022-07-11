/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../InterestRateModule.sol";

contract InterestRateModuleTest is Test {
    using stdStorage for StdStorage;

    InterestRateModule private interestRateModule;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);

    //this is a before
    constructor() {}

    //this is a before each
    function setUp() public {
        vm.startPrank(creatorAddress);
        interestRateModule = new InterestRateModule();
        vm.stopPrank();
    }

    function testDefaultBaseInterestRate() public {
        assertEq(0, interestRateModule.baseInterestRate());
    }

    function testNonOwnerSetsBaseInterestRate(
        address unprivilegedAddress,
        uint64 baseInterestRate
    ) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        interestRateModule.setBaseInterestRate(baseInterestRate);
        vm.stopPrank();
    }

    function testOwnerSetsBaseInterestRate(uint64 baseInterestRate) public {
        vm.startPrank(creatorAddress);
        interestRateModule.setBaseInterestRate(baseInterestRate);
        vm.stopPrank();

        assertEq(baseInterestRate, interestRateModule.baseInterestRate());
    }

    function testDefaultCollateralInterestRate() public {
        for (uint256 i; i < 10; ) {
            assertEq(0, interestRateModule.creditRatingToInterestRate(i));
            unchecked {
                ++i;
            }
        }
    }

    function testNonOwnerSetsCollateralInterestRates(
        address unprivilegedAddress,
        uint64 interestRate
    ) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        uint256[] memory creditRatings = new uint256[](2);
        creditRatings[0] = 0;
        creditRatings[1] = 1;

        uint256[] memory interestRates = new uint256[](2);
        interestRates[0] = interestRate;
        interestRates[1] = interestRate;

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        interestRateModule.batchSetCollateralInterestRates(
            creditRatings,
            interestRates
        );
        vm.stopPrank();
    }

    function testOwnerSetsCollateralInterestRates(uint64 interestRate) public {
        uint256[] memory creditRatings = new uint256[](2);
        creditRatings[0] = 0;
        creditRatings[1] = 1;

        uint256[] memory interestRates = new uint256[](2);
        interestRates[0] = interestRate;
        interestRates[1] = interestRate;

        vm.startPrank(creatorAddress);
        interestRateModule.batchSetCollateralInterestRates(
            creditRatings,
            interestRates
        );
        vm.stopPrank();

        assertEq(
            interestRate,
            interestRateModule.creditRatingToInterestRate(0)
        );
        assertEq(
            interestRate,
            interestRateModule.creditRatingToInterestRate(1)
        );
    }

    function testReturnBaseInterestRateWhenNoMinimalCollateralValueIsGiven(
        uint64 baseInterestRate,
        uint256 value
    ) public {
        vm.startPrank(creatorAddress);
        interestRateModule.setBaseInterestRate(baseInterestRate);
        vm.stopPrank();

        uint256[] memory valuesPerCreditRating = new uint256[](2);
        valuesPerCreditRating[0] = value;
        valuesPerCreditRating[1] = value;

        assertEq(
            baseInterestRate,
            interestRateModule.getYearlyInterestRate(valuesPerCreditRating, 0)
        );
    }

    function testReturnBaseRateWhenNoValuesAreGiven(
        uint64 baseInterestRate,
        uint256 minCollValue
    ) public {
        vm.startPrank(creatorAddress);
        interestRateModule.setBaseInterestRate(baseInterestRate);
        vm.stopPrank();

        uint256[] memory valuesPerCreditRating = new uint256[](0);

        assertEq(
            baseInterestRate,
            interestRateModule.getYearlyInterestRate(
                valuesPerCreditRating,
                minCollValue
            )
        );
    }

    function testReturnCollateralInterestRateWithoutCategory0(
        uint128 cat1Value,
        uint128 cat2Value,
        uint128 minCollValue
    ) public {
        vm.assume(cat1Value < type(uint128).max - cat2Value);
        vm.assume(cat1Value < minCollValue);
        vm.assume(cat1Value + cat2Value > minCollValue);

        uint256[] memory creditRatings = new uint256[](3);
        creditRatings[0] = 0;
        creditRatings[1] = 1;
        creditRatings[2] = 2;

        uint256[] memory interestRates = new uint256[](3);
        interestRates[0] = 5 * 10**16;
        interestRates[1] = 2 * 10**16;
        interestRates[2] = 3 * 10**16;

        vm.startPrank(creatorAddress);
        interestRateModule.batchSetCollateralInterestRates(
            creditRatings,
            interestRates
        );
        vm.stopPrank();

        uint256 expectedInterestRate = (cat1Value * interestRates[1]) /
            minCollValue +
            ((minCollValue - cat1Value) * interestRates[2]) /
            minCollValue;

        uint256[] memory valuesPerCreditRating = new uint256[](3);
        valuesPerCreditRating[1] = cat1Value;
        valuesPerCreditRating[2] = cat2Value;

        uint256 actualInterestRate = interestRateModule.getYearlyInterestRate(
            valuesPerCreditRating,
            minCollValue
        );

        assertEq(expectedInterestRate, actualInterestRate);
    }

    function testReturnCollateralInterestRateWithCategory0(
        uint128 cat0Value,
        uint128 cat1Value,
        uint128 minCollValue
    ) public {
        vm.assume(cat1Value < type(uint128).max - cat0Value);
        vm.assume(cat1Value < minCollValue);
        vm.assume(cat1Value + cat0Value > minCollValue);

        uint256[] memory creditRatings = new uint256[](3);
        creditRatings[0] = 0;
        creditRatings[1] = 1;
        creditRatings[2] = 2;

        uint256[] memory interestRates = new uint256[](3);
        interestRates[0] = 5 * 10**16;
        interestRates[1] = 2 * 10**16;
        interestRates[2] = 3 * 10**16;

        vm.startPrank(creatorAddress);
        interestRateModule.batchSetCollateralInterestRates(
            creditRatings,
            interestRates
        );
        vm.stopPrank();

        uint256 expectedInterestRate = (cat1Value * interestRates[1]) /
            minCollValue +
            ((minCollValue - cat1Value) * interestRates[0]) /
            minCollValue;

        uint256[] memory valuesPerCreditRating = new uint256[](3);
        valuesPerCreditRating[0] = cat0Value;
        valuesPerCreditRating[1] = cat1Value;

        uint256 actualInterestRate = interestRateModule.getYearlyInterestRate(
            valuesPerCreditRating,
            minCollValue
        );

        assertEq(expectedInterestRate, actualInterestRate);
    }

    function testReturnCollateralInterestRateWithTotalValueLessThenMinimalCollateralValue(
        uint128 cat1Value,
        uint128 minCollValue
    ) public {
        vm.assume(cat1Value < minCollValue);

        uint256[] memory creditRatings = new uint256[](3);
        creditRatings[0] = 0;
        creditRatings[1] = 1;
        creditRatings[2] = 2;

        uint256[] memory interestRates = new uint256[](3);
        interestRates[0] = 5 * 10**16;
        interestRates[1] = 2 * 10**16;
        interestRates[2] = 3 * 10**16;

        vm.startPrank(creatorAddress);
        interestRateModule.batchSetCollateralInterestRates(
            creditRatings,
            interestRates
        );
        vm.stopPrank();

        uint256 expectedInterestRate = (cat1Value * interestRates[1]) /
            minCollValue +
            ((minCollValue - cat1Value) * interestRates[0]) /
            minCollValue;

        uint256[] memory valuesPerCreditRating = new uint256[](3);
        valuesPerCreditRating[1] = cat1Value;

        uint256 actualInterestRate = interestRateModule.getYearlyInterestRate(
            valuesPerCreditRating,
            minCollValue
        );

        assertEq(expectedInterestRate, actualInterestRate);
    }

    function testReturnSumOfBaseAndCollateralInterestRates(
        uint64 baseInterestRate,
        uint64 collateralInterestRate,
        uint128 cat1Value,
        uint128 minCollValue
    ) public {
        vm.assume(cat1Value > minCollValue);
        vm.assume(minCollValue > 0);
        vm.assume(collateralInterestRate > 0);
        vm.assume(
            cat1Value < type(uint128).max / uint128(collateralInterestRate)
        );
        vm.assume(baseInterestRate < type(uint64).max - collateralInterestRate);

        vm.startPrank(creatorAddress);
        interestRateModule.setBaseInterestRate(baseInterestRate);
        vm.stopPrank();

        uint256[] memory creditRatings = new uint256[](1);
        creditRatings[0] = 1;

        uint256[] memory interestRates = new uint256[](1);
        interestRates[0] = uint256(collateralInterestRate);

        vm.startPrank(creatorAddress);
        interestRateModule.batchSetCollateralInterestRates(
            creditRatings,
            interestRates
        );
        vm.stopPrank();

        uint256 expectedInterestRate = uint256(baseInterestRate) +
            uint256(collateralInterestRate);

        uint256[] memory valuesPerCreditRating = new uint256[](3);
        valuesPerCreditRating[1] = cat1Value;

        uint256 actualInterestRate = interestRateModule.getYearlyInterestRate(
            valuesPerCreditRating,
            minCollValue
        );

        assertEq(expectedInterestRate, actualInterestRate);
    }
}
