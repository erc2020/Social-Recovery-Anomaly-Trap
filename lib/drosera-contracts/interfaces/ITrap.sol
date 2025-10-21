// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITrap {
    /// @dev Emitted when a new `Trap` is created.
    /// @param creator The address that created the `Trap`.
    /// @param trapId The ID of the `Trap`.
    /// @param token The address of the token used in the `Trap`.
    /// @param amount The amount of tokens deposited into the `Trap`.
    /// @param startTime The timestamp when the `Trap` becomes active.
    /// @param endTime The timestamp when the `Trap` expires.
    /// @param maxClaimable The maximum amount that can be claimed from the `Trap`.
    event TrapCreated(
        address indexed creator,
        uint256 indexed trapId,
        IERC20 indexed token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        uint256 maxClaimable
    );

    /// @dev Emitted when tokens are claimed from a `Trap`.
    /// @param claimer The address that claimed tokens.
    /// @param trapId The ID of the `Trap`.
    /// @param amount The amount of tokens claimed.
    event Claimed(address indexed claimer, uint256 indexed trapId, uint256 amount);

    /// @dev Emitted when a `Trap` is cancelled.
    /// @param canceller The address that cancelled the `Trap`.
    /// @param trapId The ID of the `Trap`.
    /// @param refundAmount The amount of tokens refunded to the creator.
    event Cancelled(address indexed canceller, uint256 indexed trapId, uint256 refundAmount);

    /// @dev Creates a new `Trap`.
    /// @param _token The address of the token to be used in the `Trap`.
    /// @param _amount The amount of tokens to deposit into the `Trap`.
    /// @param _startTime The timestamp when the `Trap` becomes active.
    /// @param _endTime The timestamp when the `Trap` expires.
    /// @param _maxClaimable The maximum amount that can be claimed from the `Trap`.
    /// @return trapId The ID of the created `Trap`.
    function createTrap(
        IERC20 _token,
        uint256 _amount,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxClaimable
    ) external returns (uint256 trapId);

    /// @dev Claims tokens from a `Trap`.
    /// @param _trapId The ID of the `Trap`.
    /// @param _amount The amount of tokens to claim.
    function claim(uint256 _trapId, uint256 _amount) external;

    /// @dev Cancels an active `Trap` and refunds remaining tokens to the creator.
    /// @param _trapId The ID of the `Trap`.
    function cancel(uint256 _trapId) external;

    /// @dev Returns the details of a `Trap`.
    /// @param _trapId The ID of the `Trap`.
    /// @return creator The address that created the `Trap`.
    /// @return token The address of the token used in the `Trap`.
    /// @return amount The total amount of tokens deposited into the `Trap`.
    /// @return startTime The timestamp when the `Trap` becomes active.
    /// @return endTime The timestamp when the `Trap` expires.
    /// @return maxClaimable The maximum amount that can be claimed from the `Trap`.
    /// @return totalClaimed The total amount of tokens claimed from the `Trap`.
    function getTrap(
        uint256 _trapId
    )
        external
        view
        returns (
            address creator,
            IERC20 token,
            uint256 amount,
            uint256 startTime,
            uint256 endTime,
            uint256 maxClaimable,
            uint256 totalClaimed
        );

    /// @dev Returns the amount of tokens that can be claimed by a specific address from a `Trap`.
    /// @param _trapId The ID of the `Trap`.
    /// @param _claimer The address of the claimer.
    /// @return claimableAmount The amount of tokens that can be claimed.
    function getClaimableAmount(uint256 _trapId, address _claimer) external view returns (uint256 claimableAmount);
}
