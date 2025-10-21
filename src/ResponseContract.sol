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
     * @dev HARDCODED address of the MockSocialRecoveryWallet.
     * In a real-world deployment, this would be the address of the actual
     * social recovery wallet you want to protect. This address must be
     * set before deployment.
     */
    MockSocialRecoveryWallet constant socialRecoveryWallet = MockSocialRecoveryWallet(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f); // Placeholder Address

    /**
     * @notice This function is called by the Drosera infrastructure when the
     * SocialRecoveryAnomalyTrap's `shouldRespond` returns true. It calls the
     * `activateTimelock` function on the monitored wallet.
     * @param responseData The encoded data from the trap, not used in this simple case.
     */
    function triggerTimelock(bytes calldata responseData) external {
        // The responseData is available if needed, but for this simple response,
        // we just perform a direct action.
        socialRecoveryWallet.activateTimelock();
    }
}
