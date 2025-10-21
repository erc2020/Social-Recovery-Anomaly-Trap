// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockSocialRecoveryWallet
 * @dev This is a mock contract for a social recovery wallet. It is intended for
 * testing the SocialRecoveryAnomalyTrap on the Ethereum Hoodi Network.
 * It simulates the core functionalities needed for the trap to monitor, such as
 * managing guardians and activating a security timelock.
 */
contract MockSocialRecoveryWallet {
    address[] public guardians;
    bool public isTimelockActive;
    uint256 public timelockEndTime;

    address private owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address[] memory initialGuardians) {
        owner = msg.sender;
        guardians = initialGuardians;
    }

    /**
     * @notice Returns the list of current guardian addresses.
     * @return An array of guardian addresses.
     */
    function getGuardians() external view returns (address[] memory) {
        return guardians;
    }

    /**
     * @notice Simulates changing the guardian list. In a real scenario, this
     * would be a protected function. For this mock, it's open for testing.
     * @param _newGuardians The new list of guardian addresses.
     */
    function changeGuardians(address[] memory _newGuardians) external {
        // In a real contract, this would have more robust access control.
        guardians = _newGuardians;
    }

    /**
     * @notice Activates a security timelock for a predefined duration (e.g., 7 days).
     * This function is intended to be called by the ResponseContract when the trap triggers.
     */
    function activateTimelock() external {
        // In a real implementation, you'd add a check to ensure only the trusted
        // response contract can call this.
        isTimelockActive = true;
        timelockEndTime = block.timestamp + 7 days;
    }
}
