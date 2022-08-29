/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../ReserveFund.sol";
import "../mockups/ERC20SolmateMock.sol";

contract ReserveFundTest is Test {
    ReserveFund private reserveFund;
    ERC20Mock private stable;

    address private ownerAddress = address(1);
    address private liquidatorAddress = address(2);
    address private randomAddress = address(3);

    //this is a before each
    function setUp() public {
        vm.startPrank(ownerAddress);
        reserveFund = new ReserveFund();
        stable = new ERC20Mock("Test Stable Coin", "USD", 18);
        stable.mint(address(reserveFund), 100e18);
        vm.stopPrank();
    }

    function testOwnerSetLiquidator() public {
        vm.startPrank(ownerAddress);
        reserveFund.setLiquidator(address(liquidatorAddress));
        vm.stopPrank();

        assertEq(reserveFund.getLiquidator(), address(liquidatorAddress));
    }

    function testUserSetLiquidator() public {
        vm.startPrank(randomAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        reserveFund.setLiquidator(address(randomAddress));
        vm.stopPrank();
    }

    function testOwnerOrLiquidatorWithdraw() public {
        vm.startPrank(ownerAddress);
        reserveFund.withdraw(50e18, address(stable), address(ownerAddress));
        vm.stopPrank();
        assertEq(stable.balanceOf(address(ownerAddress)), 50e18);
        
        // set liquidator for testing liquidator withdraw
        vm.startPrank(ownerAddress);
        reserveFund.setLiquidator(address(liquidatorAddress));
        vm.stopPrank();

        vm.startPrank(liquidatorAddress);
        reserveFund.withdraw(50e18, address(stable), address(liquidatorAddress));
        vm.stopPrank();
        assertEq(stable.balanceOf(address(liquidatorAddress)), 50e18);
    }

    function testNonOwnerOrNonLiquidatorWithdraw() public {
        vm.startPrank(randomAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        reserveFund.withdraw(50e18, address(stable), address(randomAddress));
        vm.stopPrank();
        assertEq(stable.balanceOf(randomAddress), 0);
    }

}