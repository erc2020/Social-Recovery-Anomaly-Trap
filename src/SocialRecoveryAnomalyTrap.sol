// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";
import {MockSocialRecoveryWallet} from "./MockSocialRecoveryWallet.sol";

/// @title SocialRecoveryAnomalyTrap
/// @notice Detects large, rapid changes to a social recovery wallet's guardian set.
contract SocialRecoveryAnomalyTrap is ITrap {
    // Set to the wallet you want to monitor (mock in this PoC)
    MockSocialRecoveryWallet public constant WALLET =
        MockSocialRecoveryWallet(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f);

    // More than half of guardians changed ⇒ trigger.
    uint256 public constant MAJORITY_DIVISOR = 2;

    struct CollectOutput {
        address[] guardians;      // raw guardians (will be sorted in shouldRespond)
        uint256 blockNumber;
        uint256 chainId;
    }

    constructor() {}

    // --- collect (view) ---
    function collect() external view override returns (bytes memory) {
        address[] memory g = WALLET.getGuardians();
        return abi.encode(
            CollectOutput({
                guardians: g,
                blockNumber: block.number,
                chainId: block.chainid
            })
        );
    }

    // --- shouldRespond (pure) ---
    // data[0] = current, data[1] = previous, data[n-1] oldest
    function shouldRespond(bytes[] calldata data)
        external
        pure
        override
        returns (bool, bytes memory)
    {
        if (data.length < 2) return (false, bytes(""));

        CollectOutput memory cur = abi.decode(data[0], (CollectOutput));
        CollectOutput memory prev = abi.decode(data[1], (CollectOutput));

        uint256 n = cur.guardians.length;
        if (n == 0) return (false, bytes(""));

        // Compare sets (order-independent)
        address[] memory A = _sortedCopy(cur.guardians);
        address[] memory B = _sortedCopy(prev.guardians);

        // Count how many addresses in B disappeared from A (removals),
        // plus how many in A were not in B (additions).
        (uint256 removed, uint256 added) = _diffCounts(A, B);
        uint256 changed = removed + added;

        // Threshold: > half of previous guardians replaced/added/removed.
        uint256 threshold = B.length / MAJORITY_DIVISOR;
        bool crossedNow = changed > threshold;

        // Rising-edge: if we have a third sample, ensure we didn't already cross.
        if (crossedNow && data.length >= 3) {
            CollectOutput memory prev2 = abi.decode(data[2], (CollectOutput));
            address[] memory C = _sortedCopy(prev2.guardians);
            (uint256 removedPrev, uint256 addedPrev) = _diffCounts(B, C);
            uint256 changedPrev = removedPrev + addedPrev;
            bool crossedBefore = changedPrev > (C.length / MAJORITY_DIVISOR);
            if (crossedBefore) return (false, bytes(""));
        }

        if (!crossedNow) return (false, bytes(""));

        // Evidence: hash the sorted sets + counts to make auditing easy
        bytes32 evidence = keccak256(abi.encode(A, B, changed, cur.blockNumber, cur.chainId));
        return (true, abi.encode(evidence, changed, cur.blockNumber, cur.chainId));
    }

    // ---- helpers (pure) ----

    // Insertion sort (addresses). Fine for small guardian sets.
    function _sortedCopy(address[] memory arr) private pure returns (address[] memory out) {
        out = new address[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            address x = arr[i];
            uint256 j = i;
            while (j > 0 && out[j - 1] > x) {
                out[j] = out[j - 1];
                j--;
            }
            out[j] = x;
        }
    }

    // Two-pointer diff of sorted arrays: returns (removedFromB, addedInA)
    function _diffCounts(address[] memory A, address[] memory B) private pure returns (uint256 removed, uint256 added) {
        uint256 i = 0; // A
        uint256 j = 0; // B
        while (i < A.length || j < B.length) {
            if (i < A.length && (j == B.length || A[i] < B[j])) {
                // in A, not in B => added
                added++; i++;
            } else if (j < B.length && (i == A.length || B[j] < A[i])) {
                // in B, not in A => removed
                removed++; j++;
            } else {
                // equal
                i++; j++;
            }
        }
    }
}