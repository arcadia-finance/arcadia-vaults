/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Factory Guardian
 * @dev This module provides a mechanism that allows authorized accounts to trigger an emergency stop
 *
 */
abstract contract MainRegistryGuardian is Ownable {
    address public guardian;

    /*
    //////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////
    */

    event GuardianChanged(address indexed oldGuardian, address indexed newGuardian);
    event PauseUpdate(address account, bool withdrawPauseUpdate, bool depositPauseUpdate);

    /*
    //////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////
    */
    bool public withdrawPaused;
    bool public depositPaused;
    uint256 public pauseTimestamp;

    constructor() {}

    /*
    //////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////
    */

    /**
     * @dev Throws if called by any account other than the guardian.
     */
    modifier onlyGuardian() {
        require(msg.sender == guardian, "Guardian: Only guardian");
        _;
    }

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
     * @notice This function is used to set the guardian address
     * @param guardian_ The address of the new guardian.
     * @dev Allows onlyOwner to change the guardian address.
     */
    function changeGuardian(address guardian_) external onlyOwner {
        guardian = guardian_;
        emit GuardianChanged(guardian, guardian_);
    }

    /**
     * @notice This function is used to pause the contract.
     * @dev This function can be called by the guardian to pause all functionality in the event of an emergency.
     *      This function pauses repay, withdraw, borrow, deposit and liquidation.
     *      This function can only be called by the guardian.
     *      The guardian can only pause the protocol again after 32 days have past since the last pause.
     *      This is to prevent that a malicious guardian can take user-funds hostage for an indefinite time.
     *  After the guardian has paused the protocol, the owner has 30 days to find potential problems,
     *  find a solution and unpause the protocol. If the protocol is not unpaused after 30 days,
     *  an emergency procedure can be started by any user to unpause the protocol.
     *  All users have now at least a two-day window to withdraw assets and close positions before
     *  the protocol can again be paused (by or the owner or the guardian.
     */
    function pause() external onlyGuardian {
        require(block.timestamp > pauseTimestamp + 32 days, "G_P: Cannot pause");
        withdrawPaused = true;
        depositPaused = true;
        pauseTimestamp = block.timestamp;
        emit PauseUpdate(msg.sender, true, true);
    }

    /**
     * @notice This function is used to unpause the contract.
     * @param withdrawPaused_ Whether create functionality should be paused.
     * @param depositPaused_ Whether liquidate functionality should be paused.
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
     * @notice This function is used to unpause the contract.
     * @dev This function can unPause variables all at once.
     *      If the protocol is not unpaused after 30 days, any user can unpause the protocol.
     *  This ensures that no rogue owner or guardian can lock user funds for an indefinite amount of time.
     *  All users have now at least a two-day window to withdraw assets and close positions before
     *  the protocol can again be paused (by or the owner or the guardian.
     */
    function unPause() external {
        require(block.timestamp > pauseTimestamp + 30 days, "G_UP: Cannot unPause");
        if (withdrawPaused || depositPaused) {
            withdrawPaused = false;
            depositPaused = false;
            emit PauseUpdate(msg.sender, false, false);
        }
    }
}