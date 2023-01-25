/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity ^0.8.0;

import "./BaseGuardian.sol";

/**
 * @title Main Registry Guardian
 * @dev This module provides a mechanism that allows authorized accounts to trigger an emergency stop
 *
 */
abstract contract MainRegistryGuardian is BaseGuardian {
    /*
    //////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////
    */

    event PauseUpdate(address account, bool withdrawPauseUpdate, bool depositPauseUpdate);

    /*
    //////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////
    */
    bool public withdrawPaused;
    bool public depositPaused;

    constructor() {}

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
        require(!withdrawPaused, "Guardian: withdraw paused");
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for deposit assets
     * It throws if deposit assets is paused.
     */
    modifier whenDepositNotPaused() {
        require(!depositPaused, "Guardian: deposit paused");
        _;
    }

    /**
     * @inheritdoc BaseGuardian
     */
    function pause() external override onlyGuardian {
        require(block.timestamp > pauseTimestamp + 32 days, "G_P: Cannot pause");
        withdrawPaused = true;
        depositPaused = true;
        pauseTimestamp = block.timestamp;
        emit PauseUpdate(msg.sender, true, true);
    }

    /**
     * @notice This function is used to unpause the contract.
     * @param withdrawPaused_ Whether withdraw functionality should be paused.
     * @param depositPaused_ Whether deposit functionality should be paused.
     *      This function can unPause variables individually.
     *      Only owner can call this function. It updates the variables if incoming variable is false.
     *  If variable is false and incoming variable is true, then it does not update the variable.
     */
    function unPause(bool withdrawPaused_, bool depositPaused_) external onlyOwner {
        withdrawPaused = withdrawPaused && withdrawPaused_;
        depositPaused = depositPaused && depositPaused_;
        emit PauseUpdate(msg.sender, withdrawPaused, depositPaused);
    }

    /**
     * @inheritdoc BaseGuardian
     */
    function unPause() external override {
        require(block.timestamp > pauseTimestamp + 30 days, "G_UP: Cannot unPause");
        if (withdrawPaused || depositPaused) {
            withdrawPaused = false;
            depositPaused = false;
            emit PauseUpdate(msg.sender, false, false);
        }
    }
}
