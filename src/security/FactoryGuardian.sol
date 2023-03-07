/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity ^0.8.13;

import { BaseGuardian } from "./BaseGuardian.sol";

/**
 * @title Factory Guardian
 * @author Pragma Labs
 * @notice This module provides the logic for the Factory that allows authorized accounts to trigger an emergency stop.
 */
abstract contract FactoryGuardian is BaseGuardian {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag indicating if the create() function is paused.
    bool public createPaused;
    // Flag indicating if the liquidate() function is paused.
    bool public liquidatePaused;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event PauseUpdate(bool createPauseUpdate, bool liquidatePauseUpdate);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

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
        createPaused = true;
        liquidatePaused = true;
        pauseTimestamp = block.timestamp;
        emit PauseUpdate(true, true);
    }

    /**
     * @notice This function is used to unpause one or more flags.
     * @param createPaused_ false when create functionality should be unPaused.
     * @param liquidatePaused_ false when liquidate functionality should be unPaused.
     * @dev This function can unPause repay, withdraw, borrow, and deposit individually.
     * @dev Can only update flags from paused (true) to unPaused (false), cannot be used the other way around
     * (to set unPaused flags to paused).
     */
    function unPause(bool createPaused_, bool liquidatePaused_) external onlyOwner {
        createPaused = createPaused && createPaused_;
        liquidatePaused = liquidatePaused && liquidatePaused_;
        emit PauseUpdate(createPaused, liquidatePaused);
    }

    /**
     * @inheritdoc BaseGuardian
     */
    function unPause() external override {
        require(block.timestamp > pauseTimestamp + 30 days, "G_UP: Cannot unPause");
        if (createPaused || liquidatePaused) {
            createPaused = false;
            liquidatePaused = false;
            emit PauseUpdate(false, false);
        }
    }
}
