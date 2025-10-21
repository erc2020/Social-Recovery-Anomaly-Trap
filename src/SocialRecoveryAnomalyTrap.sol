// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";
import {MockSocialRecoveryWallet} from "./MockSocialRecoveryWallet.sol";

/**
 * @title SocialRecoveryAnomalyTrap
 * @dev This trap monitors a social recovery wallet for rapid, significant changes
 * to its list of guardians. It is designed to be a stateless, reactive security
 * measure within the Drosera network.
 *
 * It works by comparing snapshots of the guardian list. If a majority of guardians
 * are changed within a short period, the trap triggers a response.
 */
contract SocialRecoveryAnomalyTrap {
    /**
     * @dev HARDCODED address of the MockSocialRecoveryWallet to monitor.
     * This must be replaced with the actual wallet address before deployment.
     */
    MockSocialRecoveryWallet constant socialRecoveryWallet = MockSocialRecoveryWallet(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f); // Placeholder Address

    /**
     * @notice Collects the current list of guardians from the social recovery wallet.
     * This function is intended to be called periodically by whitelisted Drosera operators.
     * @return The ABI-encoded list of guardian addresses.
     */
    function collect() external view returns (bytes memory) {
        address[] memory guardians = socialRecoveryWallet.getGuardians();
        return abi.encode(guardians);
    }

    /**
     * @notice Determines if a response should be triggered by comparing two guardian lists.
     * @param data An array of ABI-encoded guardian lists from two `collect` calls.
     * @return A boolean indicating whether to respond, and the response payload.
     */
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        // We need at least two snapshots to compare.
        if (data.length < 2) {
            return (false, "");
        }

        // Decode the guardian lists from the two most recent snapshots.
        address[] memory guardiansBefore = abi.decode(data[0], (address[]));
        address[] memory guardiansAfter = abi.decode(data[1], (address[]));

        uint256 totalGuardians = guardiansBefore.length;
        // Avoid division by zero if the wallet has no guardians.
        if (totalGuardians == 0) {
            return (false, "");
        }

        uint256 changedGuardians = _countChangedGuardians(guardiansBefore, guardiansAfter);

        // Define the trigger threshold: a change in more than half of the guardians.
        uint256 threshold = totalGuardians / 2;

        bool triggered = changedGuardians > threshold;

        if (triggered) {
            // Encode data to pass to the response contract if needed.
            bytes memory responseData = abi.encode(guardiansBefore, guardiansAfter, changedGuardians);
            return (true, responseData);
        }

        return (false, "");
    }

    /**
     * @dev Internal pure function to count the number of guardians that are different
     * between two lists. It works by checking how many guardians from the first list
     * are no longer present in the second list.
     * @param listA The first list of guardian addresses.
     * @param listB The second list of guardian addresses.
     * @return The number of guardians that have been changed or removed.
     */
    function _countChangedGuardians(address[] memory listA, address[] memory listB) internal pure returns (uint256) {
        uint256 removedCount = 0;
        for (uint i = 0; i < listA.length; i++) {
            bool found = false;
            for (uint j = 0; j < listB.length; j++) {
                if (listA[i] == listB[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                removedCount++;
            }
        }
        return removedCount;
    }
}
