/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity ^0.8.0;

import {BaseGuardian} from "./BaseGuardian.sol";

/**
 * @title Factory Guardian
 * @dev This module provides a mechanism that allows authorized accounts to trigger an emergency stop
 *
 */
abstract contract FactoryGuardian is BaseGuardian {
    /*
    //////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////
    */

    event PauseUpdate(address account, bool createPauseUpdate, bool liquidatePauseUpdate);

    /*
    //////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////
    */
    bool public createPaused;
    bool public liquidatePaused;

    constructor() {}

    /*
    //////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////
    */

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for create vault.
     * It throws if create vault is paused.
     */
    modifier whenCreateNotPaused() {
        require(!createPaused, "Guardian: create paused");
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for liquidate vaultq.
     * It throws if liquidate vault is paused.
     */
    modifier whenLiquidateNotPaused() {
        require(!liquidatePaused, "Guardian: liquidate paused");
        _;
    }

    /**
     * @inheritdoc BaseGuardian
     */
    function pause() external override onlyGuardian {
        require(block.timestamp > pauseTimestamp + 32 days, "G_P: Cannot pause");
        createPaused = true;
        liquidatePaused = true;
        pauseTimestamp = block.timestamp;
        emit PauseUpdate(msg.sender, true, true);
    }

    /**
     * @notice This function is used to unpause the contract.
     * @param createPaused_ Whether create functionality should be paused.
     * @param liquidatePaused_ Whether liquidate functionality should be paused.
     *      This function can unPause variables individually.
     *      Only owner can call this function. It updates the variables if incoming variable is false.
     *  If variable is false and incoming variable is true, then it does not update the variable.
     */
    function unPause(bool createPaused_, bool liquidatePaused_) external onlyOwner {
        createPaused = createPaused && createPaused_;
        liquidatePaused = liquidatePaused && liquidatePaused_;
        emit PauseUpdate(msg.sender, createPaused, liquidatePaused);
    }

    /**
     * @inheritdoc BaseGuardian
     */
    function unPause() external override {
        require(block.timestamp > pauseTimestamp + 30 days, "G_UP: Cannot unPause");
        if (createPaused || liquidatePaused) {
            createPaused = false;
            liquidatePaused = false;
            emit PauseUpdate(msg.sender, false, false);
        }
    }
}
