/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity ^0.8.13;

import { Owned } from "lib/solmate/src/auth/Owned.sol";

/**
 * @title Guardian
 * @author Pragma Labs
 * @notice This module provides the base logic that allows authorized accounts to trigger an emergency stop.
 */
abstract contract BaseGuardian is Owned {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Address of the Guardian.
    address public guardian;
    // Last timestamp an emergency stop was triggered.
    uint256 public pauseTimestamp;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event GuardianChanged(address indexed oldGuardian, address indexed newGuardian);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Throws if called by any account other than the guardian.
     */
    modifier onlyGuardian() {
        require(msg.sender == guardian, "Guardian: Only guardian");
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() Owned(msg.sender) { }

    /* //////////////////////////////////////////////////////////////
                            GUARDIAN LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function is used to set the guardian address
     * @param guardian_ The address of the new guardian.
     * @dev Allows onlyOwner to change the guardian address.
     */
    function changeGuardian(address guardian_) external onlyOwner {
        emit GuardianChanged(guardian, guardian_);
        guardian = guardian_;
    }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function is used to pause all the flags of the contract.
     * @dev This function can be called by the guardian to pause all functionality in the event of an emergency.
     * This function pauses repay, withdraw, borrow, deposit and liquidation.
     * This function can only be called by the guardian.
     * The guardian can only pause the protocol again after 32 days have past since the last pause.
     * This is to prevent that a malicious guardian can take user-funds hostage for an indefinite time.
     * @dev After the guardian has paused the protocol, the owner has 30 days to find potential problems,
     * find a solution and unpause the protocol. If the protocol is not unpaused after 30 days,
     * an emergency procedure can be started by any user to unpause the protocol.
     * All users have now at least a two-day window to withdraw assets and close positions before
     * the protocol can again be paused (after 32 days).
     */
    function pause() external virtual onlyGuardian { }

    /**
     * @notice This function is used to unPause all flags.
     * @dev If the protocol is not unpaused after 30 days, any user can unpause the protocol.
     * This ensures that no rogue owner or guardian can lock user funds for an indefinite amount of time.
     * All users have now at least a two-day window to withdraw assets and close positions before
     * the protocol can again be paused (after 32 days).
     */
    function unPause() external virtual { }
}
