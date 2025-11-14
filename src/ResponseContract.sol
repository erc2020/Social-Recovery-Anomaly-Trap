// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockSocialRecoveryWallet} from "./MockSocialRecoveryWallet.sol";

/**
 * @title ResponseContract
 * @dev This contract is the response component for the SocialRecoveryAnomalyTrap.
 * Its sole purpose is to perform a predefined action when the main trap triggers.
 * The Drosera network will call the `triggerTimelock` function with the necessary payload.
 */
contract ResponseContract {
    /**
     * @dev The address of the MockSocialRecoveryWallet.
     * This is set in the constructor and is immutable.
     */
    MockSocialRecoveryWallet public immutable socialRecoveryWallet;

    /**
     * @dev The address that is allowed to call the triggerTimelock function.
     * This would typically be a Drosera executor or a TrapConfig contract.
     */
    address public immutable allowed;

    /**
     * @param _wallet The address of the social recovery wallet to protect.
     * @param _allowed The address authorized to trigger the response.
     */
    constructor(address _wallet, address _allowed) {
        socialRecoveryWallet = MockSocialRecoveryWallet(_wallet);
        allowed = _allowed;
    }

    /**
     * @notice This function is called by the Drosera infrastructure when the
     * SocialRecoveryAnomalyTrap's `shouldRespond` returns true. It calls the
     * `activateTimelock` function on the monitored wallet.
     * @param responseData The encoded data from the trap, not used in this simple case.
     */
    function triggerTimelock(bytes calldata responseData) external {
        require(msg.sender == allowed, "unauthorized");
        // The responseData is available if needed, but for this simple response,
        // we just perform a direct action.
        socialRecoveryWallet.activateTimelock();
    }
}