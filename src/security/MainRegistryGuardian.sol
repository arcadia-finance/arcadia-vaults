/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity ^0.8.13;

import { BaseGuardian } from "./BaseGuardian.sol";

/**
 * @title Registry Guardian
 * @author Pragma Labs
 * @notice This module provides the logic for the MainRegistry that allows authorized accounts to trigger an emergency stop.
 */
abstract contract MainRegistryGuardian is BaseGuardian {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag indicating if the withdraw() function is paused.
    bool public withdrawPaused;
    // Flag indicating if the deposit() function is paused.
    bool public depositPaused;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event PauseUpdate(bool withdrawPauseUpdate, bool depositPauseUpdate);

    /*
    //////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////
    */
    error FunctionIsPaused();

    /*
    //////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////
    */

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for withdraw assets.
     * It throws if withdraw is paused.
     */
    modifier whenWithdrawNotPaused() {
        if (withdrawPaused) revert FunctionIsPaused();
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for deposit assets.
     * It throws if deposit assets is paused.
     */
    modifier whenDepositNotPaused() {
        if (depositPaused) revert FunctionIsPaused();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() { }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc BaseGuardian
     */
    function pause() external override onlyGuardian {
        require(block.timestamp > pauseTimestamp + 32 days, "G_P: Cannot pause");
        withdrawPaused = true;
        depositPaused = true;
        pauseTimestamp = block.timestamp;

        emit PauseUpdate(true, true);
    }

    /**
     * @notice This function is used to unpause one or more flags.
     * @param withdrawPaused_ false when withdraw functionality should be unPaused.
     * @param depositPaused_ false when deposit functionality should be unPaused.
     * @dev This function can unPause repay, withdraw, borrow, and deposit individually.
     * @dev Can only update flags from paused (true) to unPaused (false), cannot be used the other way around
     * (to set unPaused flags to paused).
     */
    function unPause(bool withdrawPaused_, bool depositPaused_) external onlyOwner {
        withdrawPaused = withdrawPaused && withdrawPaused_;
        depositPaused = depositPaused && depositPaused_;

        emit PauseUpdate(withdrawPaused, depositPaused);
    }

    /**
     * @inheritdoc BaseGuardian
     */
    function unPause() external override {
        require(block.timestamp > pauseTimestamp + 30 days, "G_UP: Cannot unPause");
        if (withdrawPaused || depositPaused) {
            withdrawPaused = false;
            depositPaused = false;

            emit PauseUpdate(false, false);
        }
    }
}
