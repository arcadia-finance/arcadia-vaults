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
    ERC20Mock private stableCoin;

    address private ownerAddress = address(1);
    address private liquidatorAddress = address(2);
    address private randomAddress = address(3);

    //this is a before each
    function setUp() public {
        vm.startPrank(ownerAddress);
        reserveFund = new ReserveFund();
        stableCoin = new ERC20Mock("Test Stable Coin", "USD", 18);
        stableCoin.mint(address(reserveFund), 100e18);
        vm.stopPrank();
    }

    function testOwnerSetLiquidator() public {
        vm.startPrank(ownerAddress);
        reserveFund.setLiquidator(address(liquidatorAddress));
        vm.stopPrank();
    }

    function testFailUserSetLiquidator() public {
        vm.startPrank(randomAddress);
        reserveFund.setLiquidator(address(randomAddress));
        vm.stopPrank();
    }

    function testOwnerOrLiquidatorWithdraw() public {
        vm.startPrank(ownerAddress);
        reserveFund.withdraw(50e18, address(stableCoin), address(ownerAddress));
        vm.stopPrank();
        require(stableCoin.balanceOf(address(ownerAddress)) == 50e18);
        
        // set liquidator for testing liquidator withdraw
        vm.startPrank(ownerAddress);
        reserveFund.setLiquidator(address(liquidatorAddress));
        vm.stopPrank();

        vm.startPrank(liquidatorAddress);
        reserveFund.withdraw(50e18, address(stableCoin), address(liquidatorAddress));
        vm.stopPrank();
        require(stableCoin.balanceOf(address(liquidatorAddress)) == 50e18);
    }

    function testFailOwnerOrLiquidatorWithdraw() public {
        vm.startPrank(randomAddress);
        reserveFund.withdraw(50e18, address(stableCoin), address(randomAddress));
        vm.stopPrank();
    }
}