// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SocialRecoveryAnomalyTrap} from "../src/SocialRecoveryAnomalyTrap.sol";
import {ResponseContract} from "../src/ResponseContract.sol";
import {MockSocialRecoveryWallet} from "../src/MockSocialRecoveryWallet.sol";
import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

struct CollectOutput {
    address[] guardians;
    uint256 blockNumber;
    uint256 chainId;
}

contract SocialRecoveryAnomalyTrapTest is Test {
    SocialRecoveryAnomalyTrap public trap;
    MockSocialRecoveryWallet public mockWallet;
    ResponseContract public responseContract;

    address[] public initialGuardians;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address david = makeAddr("david");
    address eve = makeAddr("eve");
    address frank = makeAddr("frank");
    address grace = makeAddr("grace");

    function setUp() public {
        // Initial set of guardians
        initialGuardians.push(alice);
        initialGuardians.push(bob);
        initialGuardians.push(charlie);
        initialGuardians.push(david);

        // Deploy the mock wallet with the initial guardians
        mockWallet = new MockSocialRecoveryWallet(initialGuardians);
        address mockWalletAddress = address(mockWallet);

        // Deploy the trap
        bytes memory trapBytecode = abi.encodePacked(type(SocialRecoveryAnomalyTrap).creationCode);
        trap = SocialRecoveryAnomalyTrap(deployCode(
            "SocialRecoveryAnomalyTrap.sol:SocialRecoveryAnomalyTrap",
            _replacePlaceholder(trapBytecode, mockWalletAddress)
        ));

        // Deploy the response contract, allowing `address(this)` to call it.
        responseContract = new ResponseContract(mockWalletAddress, address(this));
    }

    /// @dev Helper to replace the hardcoded placeholder address in contract bytecode.
    function _replacePlaceholder(bytes memory code, address replacement) internal pure returns (bytes memory) {
        bytes20 placeholder = bytes20(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f);
        bytes20 newAddr = bytes20(replacement);
        
        for (uint256 i = 0; i <= code.length - 20; ++i) {
            bytes20 slice;
            assembly {
                slice := mload(add(code, add(0x20, i)))
            }
            if (slice == placeholder) {
                assembly {
                    mstore(add(code, add(0x20, i)), newAddr)
                }
            }
        }
        return code;
    }

    function test_ShouldNotTriggerWithLessThanTwoSamples() public {
        bytes[] memory collectedData = new bytes[](1);
        collectedData[0] = trap.collect();
        (bool triggered, ) = trap.shouldRespond(collectedData);
        assertFalse(triggered, "Trap should not trigger with less than two samples.");
    }

    function test_ShouldNotTriggerWithNoGuardians() public {
        // Set up a wallet with no guardians
        address[] memory emptyGuardians;
        mockWallet.changeGuardians(emptyGuardians);

        bytes[] memory collectedData = new bytes[](2);
        collectedData[1] = trap.collect(); // Previous state
        collectedData[0] = trap.collect(); // Current state
        (bool triggered, ) = trap.shouldRespond(collectedData);

        assertFalse(triggered, "Trap should not trigger when there are no guardians.");
    }

    function test_ShouldNotTriggerWithNoChange() public {
        bytes[] memory collectedData = new bytes[](2);
        collectedData[1] = trap.collect();
        collectedData[0] = trap.collect();
        (bool triggered, ) = trap.shouldRespond(collectedData);

        assertFalse(triggered, "Trap should not trigger when there are no changes in guardians.");
    }

    function test_ShouldNotTriggerIfGuardianChangeIsBelowThreshold() public {
        bytes[] memory collectedData = new bytes[](2);
        collectedData[1] = trap.collect(); // 4 guardians

        // Change one guardian (1 added, 1 removed = 2 changes). Threshold is 4/2 = 2. Not > 2.
        address[] memory newGuardians = new address[](4);
        newGuardians[0] = alice;
        newGuardians[1] = bob;
        newGuardians[2] = charlie;
        newGuardians[3] = eve; // David is replaced by Eve
        mockWallet.changeGuardians(newGuardians);
        collectedData[0] = trap.collect();

        (bool triggered, ) = trap.shouldRespond(collectedData);
        assertFalse(triggered, "Trap should not trigger when guardian changes are below the threshold.");
    }
    
    function test_ShouldTriggerIfGuardianChangeIsAboveThreshold() public {
        bytes[] memory collectedData = new bytes[](2);
        collectedData[1] = trap.collect(); // 4 guardians

        // Change 3 guardians (3 added, 3 removed = 6 changes). Threshold is 4/2 = 2. 6 > 2.
        address[] memory newGuardians = new address[](4);
        newGuardians[0] = alice;
        newGuardians[1] = eve;
        newGuardians[2] = frank;
        newGuardians[3] = grace;
        mockWallet.changeGuardians(newGuardians);
        collectedData[0] = trap.collect();

        (bool triggered, bytes memory responseData) = trap.shouldRespond(collectedData);

        assertTrue(triggered, "Trap should trigger when a majority of guardians change.");
        assertGt(responseData.length, 0, "Response data should not be empty when triggered.");
    }

    function test_ShouldHandleOrderChangeCorrectly() public {
        bytes[] memory collectedData = new bytes[](2);
        collectedData[1] = trap.collect();

        // Change the order of guardians
        address[] memory newGuardians = new address[](4);
        newGuardians[0] = david;
        newGuardians[1] = charlie;
        newGuardians[2] = bob;
        newGuardians[3] = alice;
        mockWallet.changeGuardians(newGuardians);
        collectedData[0] = trap.collect();

        (bool triggered, ) = trap.shouldRespond(collectedData);
        assertFalse(triggered, "Trap should not trigger if only the order of guardians changes.");
    }

    function test_RisingEdgeGuard() public {
        bytes[] memory collectedData = new bytes[](3);

        // State 1 (prev2): 4 guardians
        collectedData[2] = trap.collect();

        // State 2 (prev): 3 guardians changed (triggers)
        address[] memory newGuardians1 = new address[](4);
        newGuardians1[0] = alice;
        newGuardians1[1] = eve;
        newGuardians1[2] = frank;
        newGuardians1[3] = grace;
        mockWallet.changeGuardians(newGuardians1);
        collectedData[1] = trap.collect();

        // Check that it would have triggered from state 2 to 1
        bytes[] memory firstCheck = new bytes[](2);
        firstCheck[1] = collectedData[2];
        firstCheck[0] = collectedData[1];
        (bool triggeredFirst, ) = trap.shouldRespond(firstCheck);
        assertTrue(triggeredFirst, "Pre-condition failed: First change should have triggered.");

        // State 3 (cur): another change, but still above threshold
        address[] memory newGuardians2 = new address[](4);
        newGuardians2[0] = alice;
        newGuardians2[1] = eve;
        newGuardians2[2] = frank;
        newGuardians2[3] = makeAddr("heidi");
        mockWallet.changeGuardians(newGuardians2);
        collectedData[0] = trap.collect();

        // Now check with all 3 samples. It should not trigger because it was already triggered.
        (bool triggeredSecond, ) = trap.shouldRespond(collectedData);
        assertFalse(triggeredSecond, "Rising-edge guard should prevent re-triggering.");
    }

    function test_ResponseContractActivatesTimelock() public {
        assertFalse(mockWallet.isTimelockActive(), "Timelock should be inactive initially.");

        bytes[] memory collectedData = new bytes[](2);
        collectedData[1] = trap.collect();
        
        address[] memory newGuardians = new address[](4);
        newGuardians[0] = eve;
        newGuardians[1] = frank;
        newGuardians[2] = grace;
        newGuardians[3] = alice;
        mockWallet.changeGuardians(newGuardians);
        collectedData[0] = trap.collect();

        (bool triggered, bytes memory responseData) = trap.shouldRespond(collectedData);
        assertTrue(triggered, "Trap must trigger to test response.");

        // Call the response contract from the authorized address
        responseContract.triggerTimelock(responseData);

        assertTrue(mockWallet.isTimelockActive(), "Timelock should be active after response.");
    }

    function test_ResponseContractRevertsForUnauthorizedCaller() public {
        bytes[] memory collectedData = new bytes[](2);
        collectedData[1] = trap.collect();
        
        address[] memory newGuardians = new address[](4);
        newGuardians[0] = eve;
        newGuardians[1] = frank;
        newGuardians[2] = grace;
        newGuardians[3] = alice;
        mockWallet.changeGuardians(newGuardians);
        collectedData[0] = trap.collect();

        (bool triggered, bytes memory responseData) = trap.shouldRespond(collectedData);
        assertTrue(triggered, "Trap must trigger to test response.");

        // Attempt to call from an unauthorized address
        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert("unauthorized");
        responseContract.triggerTimelock(responseData);
    }

    function test_CollectFunctionReturnsCorrectData() public {
        uint256 blockNumberBefore = block.number;
        uint256 chainId = block.chainid;

        bytes memory collectedData = trap.collect();
        CollectOutput memory output = abi.decode(collectedData, (CollectOutput));

        address[] memory expectedGuardians = mockWallet.getGuardians();

        assertEq(output.guardians.length, expectedGuardians.length, "Collected guardians length mismatch.");
        for (uint i = 0; i < expectedGuardians.length; i++) {
            assertEq(output.guardians[i], expectedGuardians[i], "Mismatch in collected guardian address.");
        }
        assertEq(output.blockNumber, block.number, "Block number mismatch.");
        assertEq(output.chainId, chainId, "Chain ID mismatch.");
    }
}