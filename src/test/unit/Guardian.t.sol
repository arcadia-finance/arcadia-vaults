/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../../lib/forge-std/src/Test.sol";
import { FactoryGuardian } from "../../security/FactoryGuardian.sol";
import { MainRegistryGuardian } from "../../security/MainRegistryGuardian.sol";
import { BaseGuardian } from "../../security/BaseGuardian.sol";

contract BaseGuardianPossibleExtension is BaseGuardian {
    bool public pausedVar1;
    bool public pausedVar2;

    function pause() external override onlyGuardian {
        require(block.timestamp > pauseTimestamp + 32 days, "G_P: Cannot pause");
        pausedVar1 = true;
        pausedVar2 = true;
        pauseTimestamp = block.timestamp;
    }

    function unPause(bool pausedVar1_, bool pausedVar2_) external onlyOwner {
        pausedVar1 = pausedVar1 && pausedVar1_;
        pausedVar2 = pausedVar2 && pausedVar2_;
    }

    function unPause() external override {
        require(block.timestamp > pauseTimestamp + 30 days, "G_UP: Cannot unPause");
        if (pausedVar1 || pausedVar2) {
            pausedVar1 = false;
            pausedVar2 = false;
        }
    }

    function resetPauseVars() external onlyOwner {
        pausedVar1 = false;
        pausedVar2 = false;
    }
}

contract MainRegistryMockup is MainRegistryGuardian {
    uint256 public storedIncrement;

    function depositGuarded(uint256) external whenDepositNotPaused {
        storedIncrement += 1;
    }

    function withdrawUnguarded(uint256) external {
        storedIncrement += 1;
    }

    function withdrawGuarded(uint256) external whenWithdrawNotPaused {
        storedIncrement += 1;
    }

    function reset() external onlyOwner {
        storedIncrement = 0;
    }

    function resetPauseVars() external onlyOwner {
        withdrawPaused = false;
        depositPaused = false;
    }
}

contract FactoryMockup is FactoryGuardian {
    uint256 public storedIncrement;

    function createGuarded(uint256) external whenCreateNotPaused {
        storedIncrement += 1;
    }

    function liquidateUnguarded(uint256) external {
        storedIncrement += 1;
    }

    function liquidateGuarded(uint256) external whenLiquidateNotPaused {
        storedIncrement += 1;
    }

    function reset() external onlyOwner {
        storedIncrement = 0;
    }

    function resetPauseVars() external onlyOwner {
        createPaused = false;
        liquidatePaused = false;
    }
}

contract BaseGuardianUnitTest is Test {
    using stdStorage for StdStorage;

    BaseGuardianPossibleExtension baseGuardian;
    address guardian = address(1);
    address owner = address(2);

    event GuardianChanged(address indexed oldGuardian, address indexed newGuardian);

    constructor() {
        vm.startPrank(owner);
        baseGuardian = new BaseGuardianPossibleExtension();
        baseGuardian.changeGuardian(guardian);
        vm.warp(60 days);
        vm.stopPrank();
    }

    function testRevert_changeGuardian_onlyOwner(address nonOwner_) public {
        // Given: the contract owner is owner
        vm.assume(nonOwner_ != owner);
        vm.startPrank(nonOwner_);
        // When: a non-owner tries to change the guardian, it is reverted
        vm.expectRevert("UNAUTHORIZED");
        baseGuardian.changeGuardian(guardian);
        vm.stopPrank();
        // Then: the guardian is not changed
        assertEq(baseGuardian.guardian(), guardian);
    }

    function testSuccess_changeGuardian(address newGuardian_) public {
        // Preprocess: set the new guardian
        vm.assume(newGuardian_ != address(0));
        vm.assume(newGuardian_ != guardian);
        vm.assume(newGuardian_ != owner);
        // Given: the contract owner is owner
        vm.startPrank(owner);
        // When: the owner changes the guardian
        vm.expectEmit(true, true, true, true);
        emit GuardianChanged(guardian, newGuardian_);
        baseGuardian.changeGuardian(newGuardian_);
        vm.stopPrank();
        // Then: the guardian is changed
        assertEq(baseGuardian.guardian(), newGuardian_);
    }

    function testRevert_pause_onlyGuard(address pauseCaller) public {
        vm.assume(pauseCaller != guardian);
        // Given When Then: the contract is not paused
        vm.expectRevert("Guardian: Only guardian");
        vm.startPrank(pauseCaller);
        baseGuardian.pause();
        vm.stopPrank();
    }

    function testRevert_pause_timeNotExpired(uint256 timePassedAfterPause) public {
        vm.assume(timePassedAfterPause < 32 days);

        // Given: the contract is paused
        vm.startPrank(guardian);
        baseGuardian.pause();
        vm.stopPrank();

        // Given: 1 day passed
        uint256 startTimestamp = block.timestamp;
        vm.warp(startTimestamp + 1 days);

        // When: the owner unPauses
        vm.startPrank(owner);
        baseGuardian.unPause(false, false);
        vm.stopPrank();

        // Then: the guardian cannot pause again until 32 days passed from the first pause
        vm.warp(startTimestamp + timePassedAfterPause);
        vm.expectRevert("G_P: Cannot pause");
        vm.startPrank(guardian);
        baseGuardian.pause();
        vm.stopPrank();
    }

    function testRevert_pause_guardianCannotPauseAgainBetween30and32Days(uint8 deltaTimePassedAfterPause) public {
        // Preprocess: the delta time passed after pause is between 30 and 32 days
        vm.assume(deltaTimePassedAfterPause <= 2 days);
        uint256 timePassedAfterPause = 30 days + deltaTimePassedAfterPause;

        // Given: the contract is paused
        vm.startPrank(guardian);
        baseGuardian.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the guardian tries pause
        vm.startPrank(guardian);
        // Then: the guardian cannot pause again until 32 days passed from the first pause
        vm.expectRevert("G_P: Cannot pause");
        baseGuardian.pause();
        vm.stopPrank();
    }

    function testSuccess_pause_guardianCanPauseAgainAfter32days(uint32 timePassedAfterPause, address user) public {
        // Preprocess: the delta time passed after pause is between 30 and 32 days
        vm.assume(timePassedAfterPause > 32 days);
        vm.assume(user != address(0));
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is paused
        vm.startPrank(guardian);
        baseGuardian.pause();
        vm.stopPrank();

        uint256 startTimestamp = block.timestamp;
        // Given: 30 days passed after the pause and user unpauses
        vm.warp(startTimestamp + 30 days + 1);
        vm.startPrank(user);
        baseGuardian.unPause();
        vm.stopPrank();

        // Given: Sometime passed after the initial pause
        vm.warp(startTimestamp + timePassedAfterPause);

        // When: the guardian unPause
        vm.startPrank(guardian);
        // Then: the guardian can pause again because time passed
        baseGuardian.pause();
        vm.stopPrank();
    }

    function testRevert_unPause_userCannotUnPauseBefore30Days(uint256 timePassedAfterPause, address user) public {
        vm.assume(timePassedAfterPause < 30 days);
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is paused
        vm.startPrank(guardian);
        baseGuardian.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the user tries to unPause
        vm.expectRevert("G_UP: Cannot unPause");
        vm.startPrank(user);
        baseGuardian.unPause();
        vm.stopPrank();
    }

    function testSuccess_unPause_userCanUnPauseAfter30Days(uint256 deltaTimePassedAfterPause, address user) public {
        // Preprocess: the delta time passed after pause is at least 30 days
        vm.assume(deltaTimePassedAfterPause <= 120 days);
        vm.assume(deltaTimePassedAfterPause > 0);
        uint256 timePassedAfterPause = 30 days + deltaTimePassedAfterPause;
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is paused
        vm.startPrank(guardian);
        baseGuardian.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the user unPause
        vm.startPrank(user);
        baseGuardian.unPause();
        vm.stopPrank();

        // Then: the variables are updated
        assertEq(baseGuardian.pausedVar1(), false);
        assertEq(baseGuardian.pausedVar2(), false);
    }

    function testSuccess_unPause_ownerCanUnPauseDuring30Days(uint256 timePassedAfterPause, address user) public {
        vm.assume(timePassedAfterPause <= 30 days);
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is paused
        vm.startPrank(guardian);
        baseGuardian.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the owner unPauses the second variable
        vm.startPrank(owner);
        baseGuardian.unPause(true, false);
        vm.stopPrank();

        // Then: the var1 paused var2 is not paused
        assertEq(baseGuardian.pausedVar1(), true);
        assertEq(baseGuardian.pausedVar2(), false);
    }
}

contract MainRegistryGuardianUnitTest is Test {
    using stdStorage for StdStorage;

    MainRegistryMockup mainRegistry;
    address guardian = address(1);
    address owner = address(2);

    event PauseUpdate(bool withdrawPauseUpdate, bool depositPauseUpdate);

    constructor() {
        vm.startPrank(owner);
        mainRegistry = new MainRegistryMockup();
        mainRegistry.changeGuardian(guardian);
        vm.warp(60 days);
        vm.stopPrank();
    }

    function testSuccess_unPause_onlyUnpausePossible(uint256 timePassedAfterPause, address user) public {
        vm.assume(timePassedAfterPause <= 30 days);
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is paused
        vm.startPrank(guardian);

        mainRegistry.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the owner unPauses the deposit
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, false);
        mainRegistry.unPause(true, false);
        vm.stopPrank();

        // When: the owner attempts the pause the deposit from the unPause
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, false);
        mainRegistry.unPause(true, true);
        vm.stopPrank();

        // Then: the user can still deposit because the once the deposit is unPaused, it cannot be paused
        vm.startPrank(user);
        mainRegistry.depositGuarded(100);
        vm.stopPrank();

        // Then: the increment is updated
        assertEq(mainRegistry.storedIncrement(), 1);
    }

    function testSuccess_unPause_onlyToggleToUnpause(
        uint32 timePassedAfterPause,
        bool withdrawPaused,
        bool depositPaused
    ) public {
        // Preprocess:
        vm.assume(timePassedAfterPause <= 365 days);

        // Given: the contract is paused
        vm.startPrank(guardian);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, true);
        mainRegistry.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        bool previousDepositPaused = mainRegistry.depositPaused();
        bool previousWithdrawPaused = mainRegistry.withdrawPaused();

        // When: the owner unPauses
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(withdrawPaused, depositPaused);
        mainRegistry.unPause(withdrawPaused, depositPaused);
        vm.stopPrank();

        // Then: the pause variables in the contract should be turned into false if the incoming data is false.
        // True does not change the state
        assertEq(mainRegistry.depositPaused(), depositPaused && previousDepositPaused);
        assertEq(mainRegistry.withdrawPaused(), withdrawPaused && previousWithdrawPaused);
    }

    function testRevert_depositGuarded_paused(address user) public {
        vm.assume(user != owner);
        vm.assume(user != guardian);
        // Given: the contract is paused
        vm.startPrank(guardian);
        mainRegistry.pause();
        vm.stopPrank();

        // When Then: a user tries to deposit, it is reverted as paused
        vm.expectRevert("Guardian: deposit paused");
        vm.startPrank(user);
        mainRegistry.depositGuarded(100);
        vm.stopPrank();

        // Then: the increment is not updated
        assertEq(mainRegistry.storedIncrement(), 0);

        // When: owner can unPauses the withdraw
        vm.startPrank(owner);
        mainRegistry.unPause(false, true);
        vm.stopPrank();

        // Then: user tries to borrow, which is not paused
        vm.startPrank(user);
        mainRegistry.withdrawGuarded(100);
        vm.stopPrank();

        // Then: the total borrow is updated
        assertEq(mainRegistry.storedIncrement(), 1);
    }

    function testSuccess_depositGuarded_notPause(address user) public {
        // Preprocess: set the user
        vm.assume(user != address(0));
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is not paused
        vm.startPrank(user);
        // When: a user supplies
        mainRegistry.depositGuarded(100);
        vm.stopPrank();
        // Then: the increment is updated
        assertEq(mainRegistry.storedIncrement(), 1);
    }

    function testRevert_withdrawGuarded_paused(address user) public {
        // Preprocess: set the user
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is paused
        vm.startPrank(guardian);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, true);
        mainRegistry.pause();
        vm.stopPrank();

        // Given: only withdraw left paused
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, false);
        mainRegistry.unPause(true, false);
        vm.stopPrank();

        // When: a user tries to deposit
        vm.startPrank(user);
        mainRegistry.depositGuarded(100);
        vm.stopPrank();

        // Then: the increment is updated
        assertEq(mainRegistry.storedIncrement(), 1);

        // When: user tries to borrow, which is paused
        vm.expectRevert("Guardian: withdraw paused");
        vm.startPrank(user);
        mainRegistry.withdrawGuarded(100);
        vm.stopPrank();

        // Then: the increment is not updated
        assertEq(mainRegistry.storedIncrement(), 1);
    }

    function testSuccess_borrowUnguarded_notPaused(address user) public {
        // Preprocess: set the user
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is paused
        vm.startPrank(guardian);
        mainRegistry.pause();
        vm.stopPrank();

        // When: a user borrows from unguarded function
        vm.startPrank(user);
        mainRegistry.withdrawUnguarded(100);
        vm.stopPrank();

        // Then: the total borrow is updated
        assertEq(mainRegistry.storedIncrement(), 1);
    }
}

contract FactoryGuardianUnitTest is Test {
    using stdStorage for StdStorage;

    FactoryMockup factory;
    address guardian = address(1);
    address owner = address(2);

    event PauseUpdate(bool createPauseUpdate, bool liquidatePauseUpdate);

    constructor() {
        vm.startPrank(owner);
        factory = new FactoryMockup();
        factory.changeGuardian(guardian);
        vm.warp(60 days);
        vm.stopPrank();
    }

    function testSuccess_unPause_onlyUnpausePossible(uint256 timePassedAfterPause, address user) public {
        vm.assume(timePassedAfterPause <= 30 days);
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is paused
        vm.startPrank(guardian);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, true);
        factory.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the owner unPauses the liquidate
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, false);
        factory.unPause(true, false);
        vm.stopPrank();

        // When: the owner attempts the pause the liquidate from the unPause
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, false);
        factory.unPause(true, true);
        vm.stopPrank();

        // Then: the user can still liquidate because the once the liquidate is unPaused, it cannot be paused
        vm.startPrank(user);
        factory.liquidateGuarded(100);
        vm.stopPrank();

        // Then: the increment is updated
        assertEq(factory.storedIncrement(), 1);
    }

    function testSuccess_unPause_onlyToggleToUnpause(
        uint32 timePassedAfterPause,
        bool createPaused,
        bool liquidatePaused
    ) public {
        // Preprocess:
        vm.assume(timePassedAfterPause <= 365 days);

        // Given: the contract is paused
        vm.startPrank(guardian);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, true);
        factory.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        bool previousCreatePaused = factory.createPaused();
        bool previousLiquidatePaused = factory.liquidatePaused();

        // When: the owner unPauses
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(createPaused, liquidatePaused);
        factory.unPause(createPaused, liquidatePaused);
        vm.stopPrank();

        // Then: the pause variables in the contract should be turned into false if the incoming data is false.
        // True does not change the state
        assertEq(factory.createPaused(), createPaused && previousCreatePaused);
        assertEq(factory.liquidatePaused(), liquidatePaused && previousLiquidatePaused);
    }

    function testRevert_createGuarded_paused(address user) public {
        vm.assume(user != owner);
        vm.assume(user != guardian);
        // Given: the contract is paused
        vm.startPrank(guardian);
        factory.pause();
        vm.stopPrank();

        // When Then: a user tries to create, it is reverted as paused
        vm.expectRevert("Guardian: create paused");
        vm.startPrank(user);
        factory.createGuarded(1);
        vm.stopPrank();

        // Then: the increment is not updated
        assertEq(factory.storedIncrement(), 0);

        // When: owner can unPauses the create
        vm.startPrank(owner);
        factory.unPause(false, true);
        vm.stopPrank();

        // Then: user tries to create, which is not paused
        vm.startPrank(user);
        factory.createGuarded(100);
        vm.stopPrank();

        // Then: the total borrow is updated
        assertEq(factory.storedIncrement(), 1);
    }

    function testSuccess_createGuarded_notPause(address user) public {
        // Preprocess: set the user
        vm.assume(user != address(0));
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is not paused
        vm.startPrank(user);
        // When: a user supplies
        factory.createGuarded(100);
        vm.stopPrank();
        // Then: the increment is updated
        assertEq(factory.storedIncrement(), 1);
    }

    function testRevert_liquidateGuarded_paused(address user) public {
        // Preprocess: set the user
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is paused
        vm.startPrank(guardian);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, true);
        factory.pause();
        vm.stopPrank();

        // Given: only create left paused
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, false);
        factory.unPause(true, false);
        vm.stopPrank();

        // When: a user tries to liquidate
        vm.startPrank(user);
        factory.liquidateGuarded(100);
        vm.stopPrank();

        // Then: the increment is updated
        assertEq(factory.storedIncrement(), 1);

        // When: user tries to create, which is paused
        vm.expectRevert("Guardian: create paused");
        vm.startPrank(user);
        factory.createGuarded(100);
        vm.stopPrank();

        // Then: the increment is not updated
        assertEq(factory.storedIncrement(), 1);
    }

    function testSuccess_liquidateUnguarded_notPaused(address user) public {
        // Preprocess: set the user
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the contract is paused
        vm.startPrank(guardian);
        factory.pause();
        vm.stopPrank();

        // When: a user borrows from unguarded function
        vm.startPrank(user);
        factory.liquidateUnguarded(100);
        vm.stopPrank();

        // Then: the total borrow is updated
        assertEq(factory.storedIncrement(), 1);
    }
}
