// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SocialRecoveryAnomalyTrap} from "../src/SocialRecoveryAnomalyTrap.sol";
import {ResponseContract} from "../src/ResponseContract.sol";
import {MockSocialRecoveryWallet} from "../src/MockSocialRecoveryWallet.sol";

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

    function setUp() public {
        // Initial set of guardians
        initialGuardians.push(alice);
        initialGuardians.push(bob);
        initialGuardians.push(charlie);
        initialGuardians.push(david);

        // Deploy the mock wallet with the initial guardians
        mockWallet = new MockSocialRecoveryWallet(initialGuardians);

        // Deploy the trap and response contracts
        // We must use `vm.etch` to set the hardcoded address in the bytecode
        // before deploying the trap and response contracts.
        address mockWalletAddress = address(mockWallet);
        
        // Deploy Trap
        bytes memory trapBytecode = abi.encodePacked(type(SocialRecoveryAnomalyTrap).creationCode);
        trap = SocialRecoveryAnomalyTrap(deployCode(
            "SocialRecoveryAnomalyTrap.sol:SocialRecoveryAnomalyTrap",
            _replacePlaceholder(trapBytecode, mockWalletAddress)
        ));

        // Deploy Response Contract
        bytes memory responseBytecode = abi.encodePacked(type(ResponseContract).creationCode);
        responseContract = ResponseContract(deployCode(
            "ResponseContract.sol:ResponseContract",
            _replacePlaceholder(responseBytecode, mockWalletAddress)
        ));
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

    function test_ShouldNotTriggerWithNoGuardians() public {
        // 1. Set up a wallet with no guardians
        address[] memory emptyGuardians;
        mockWallet.changeGuardians(emptyGuardians);

        // 2. First collection
        bytes memory data1 = trap.collect();

        // 3. Second collection (no changes)
        bytes memory data2 = trap.collect();

        // 4. Check shouldRespond
        bytes[] memory collectedData = new bytes[](2);
        collectedData[0] = data1;
        collectedData[1] = data2;
        (bool triggered, ) = trap.shouldRespond(collectedData);

        assertFalse(triggered, "Trap should not trigger when there are no guardians.");
    }

    function test_ShouldNotTriggerIfGuardianChangeIsExactlyFiftyPercent() public {
        // 1. First collection
        bytes memory data1 = trap.collect();

        // 2. Change two out of four guardians (exactly 50%)
        address[] memory newGuardians = new address[](4);
        newGuardians[0] = alice;
        newGuardians[1] = bob;
        newGuardians[2] = eve;   // Charlie is replaced
        newGuardians[3] = makeAddr("frank"); // David is replaced
        mockWallet.changeGuardians(newGuardians);

        // 3. Second collection
        bytes memory data2 = trap.collect();

        // 4. Check shouldRespond
        bytes[] memory collectedData = new bytes[](2);
        collectedData[0] = data1;
        collectedData[1] = data2;
        (bool triggered, ) = trap.shouldRespond(collectedData);

        assertFalse(triggered, "Trap should not trigger when exactly 50% of guardians change.");
    }

    function test_ShouldNotTriggerWithNoChange() public {
        // 1. First collection
        bytes memory data1 = trap.collect();

        // 2. Second collection (no changes)
        bytes memory data2 = trap.collect();

        // 3. Check shouldRespond
        bytes[] memory collectedData = new bytes[](2);
        collectedData[0] = data1;
        collectedData[1] = data2;
        (bool triggered, ) = trap.shouldRespond(collectedData);

        assertFalse(triggered, "Trap should not trigger when there are no changes in guardians.");
    }

    function test_ShouldNotTriggerIfGuardianChangeIsBelowThreshold() public {
        // 1. First collection
        bytes memory data1 = trap.collect();

        // 2. Change one guardian (below threshold of >1)
        address[] memory newGuardians = new address[](3);
        newGuardians[0] = alice;
        newGuardians[1] = bob;
        newGuardians[2] = david; // Charlie is replaced by David
        mockWallet.changeGuardians(newGuardians);

        // 3. Second collection
        bytes memory data2 = trap.collect();

        // 4. Check shouldRespond
        bytes[] memory collectedData = new bytes[](2);
        collectedData[0] = data1;
        collectedData[1] = data2;
        (bool triggered, ) = trap.shouldRespond(collectedData);

        assertFalse(triggered, "Trap should not trigger when guardian changes are below the threshold.");
    }

    function test_ShouldTriggerIfGuardianChangeIsAboveThreshold() public {
        // 1. First collection
        bytes memory data1 = trap.collect();

        // 2. Change a majority of guardians (above threshold of >2)
        address[] memory newGuardians = new address[](4);
        newGuardians[0] = alice;
        newGuardians[1] = makeAddr("greg"); // Bob is replaced
        newGuardians[2] = eve;   // Charlie is replaced
        newGuardians[3] = makeAddr("frank"); // David is replaced
        mockWallet.changeGuardians(newGuardians);

        // 3. Second collection
        bytes memory data2 = trap.collect();

        // 4. Check shouldRespond
        bytes[] memory collectedData = new bytes[](2);
        collectedData[0] = data1;
        collectedData[1] = data2;
        (bool triggered, bytes memory responseData) = trap.shouldRespond(collectedData);

        assertTrue(triggered, "Trap should trigger when a majority of guardians change.");
        assertGt(responseData.length, 0, "Response data should not be empty when triggered.");
    }

    function test_ResponseDataIntegrity() public {
        // 1. First collection
        bytes memory data1 = trap.collect();
        address[] memory guardiansBefore = mockWallet.getGuardians();

        // 2. Change a majority of guardians
        address[] memory guardiansAfter = new address[](4);
        guardiansAfter[0] = alice;
        guardiansAfter[1] = makeAddr("grace");
        guardiansAfter[2] = eve;
        guardiansAfter[3] = makeAddr("frank");
        mockWallet.changeGuardians(guardiansAfter);

        // 3. Second collection
        bytes memory data2 = trap.collect();

        // 4. Check shouldRespond
        bytes[] memory collectedData = new bytes[](2);
        collectedData[0] = data1;
        collectedData[1] = data2;
        (bool triggered, bytes memory responseData) = trap.shouldRespond(collectedData);

        assertTrue(triggered, "Trap should trigger for response data integrity test.");

        // 5. Decode and verify responseData
        (address[] memory decodedGuardiansBefore, address[] memory decodedGuardiansAfter, uint256 changedGuardians) =
            abi.decode(responseData, (address[], address[], uint256));

        assertEq(decodedGuardiansBefore.length, guardiansBefore.length, "Decoded 'before' guardians length mismatch.");
        assertEq(decodedGuardiansAfter.length, guardiansAfter.length, "Decoded 'after' guardians length mismatch.");
        for (uint i = 0; i < guardiansBefore.length; i++) {
            assertEq(decodedGuardiansBefore[i], guardiansBefore[i], "Mismatch in 'before' guardian address.");
        }
        for (uint i = 0; i < guardiansAfter.length; i++) {
            assertEq(decodedGuardiansAfter[i], guardiansAfter[i], "Mismatch in 'after' guardian address.");
        }
        assertEq(changedGuardians, 3, "Changed guardians count mismatch.");
    }

    function test_CollectFunctionReturnsCorrectGuardians() public {
        // 1. Get guardians directly from the wallet
        address[] memory expectedGuardians = mockWallet.getGuardians();

        // 2. Collect data from the trap
        bytes memory collectedData = trap.collect();

        // 3. Decode the collected data
        address[] memory collectedGuardians = abi.decode(collectedData, (address[]));

        // 4. Compare the lists
        assertEq(collectedGuardians.length, expectedGuardians.length, "Collected guardians length mismatch.");
        for (uint i = 0; i < expectedGuardians.length; i++) {
            assertEq(collectedGuardians[i], expectedGuardians[i], "Mismatch in collected guardian address.");
        }
    }

    function test_ResponseContractActivatesTimelock() public {
        // Verify timelock is initially off
        assertFalse(mockWallet.isTimelockActive(), "Timelock should be inactive initially.");

        // Simulate a trigger and get the response data
        bytes memory data1 = trap.collect();
        address[] memory newGuardians = new address[](4);
        newGuardians[0] = makeAddr("heidi");
        newGuardians[1] = makeAddr("ivan");
        newGuardians[2] = charlie;
        newGuardians[3] = makeAddr("grace");
        mockWallet.changeGuardians(newGuardians);
        bytes memory data2 = trap.collect();
        bytes[] memory collectedData = new bytes[](2);
        collectedData[0] = data1;
        collectedData[1] = data2;
        (bool triggered, bytes memory responseData) = trap.shouldRespond(collectedData);
        assertTrue(triggered, "Trap must trigger to test response.");

        // Call the response contract
        responseContract.triggerTimelock(responseData);

        // Verify timelock is now active
        assertTrue(mockWallet.isTimelockActive(), "Timelock should be active after response.");
    }
}
