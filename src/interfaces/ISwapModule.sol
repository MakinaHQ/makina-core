// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISwapModule {
    event Swap(
        address indexed sender,
        uint16 swapperId,
        address indexed inputToken,
        address indexed outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    );
    event SwapperTargetsSet(uint16 indexed swapper, address approvalTarget, address executionTarget);

    struct SwapperTargets {
        address approvalTarget;
        address executionTarget;
    }

    /// @notice Swap order object.
    /// @param swapperId The ID of the external swap protocol.
    /// @param data The swap calldata to pass to the swapper's execution target.
    /// @param inputToken The input token.
    /// @param outputToken The output token.
    /// @param inputAmount The input amount.
    /// @param minOutputAmount The minimum expected output amount.
    struct SwapOrder {
        uint16 swapperId;
        bytes data;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 minOutputAmount;
    }

    /// @notice Returns approval and execution targets for a given swapper ID.
    /// @param swapperId The swapper ID.
    /// @return approvalTarget The approval target.
    /// @return executionTarget The execution target.
    function getSwapperTargets(uint16 swapperId)
        external
        view
        returns (address approvalTarget, address executionTarget);

    /// @notice Swaps tokens using a given swapper.
    /// @param order The swap order object.
    function swap(SwapOrder calldata order) external returns (uint256);

    /// @notice Sets approval and execution targets for a given swapper ID.
    /// @param swapperId The swapper ID.
    /// @param approvalTarget The approval target.
    function setSwapperTargets(uint16 swapperId, address approvalTarget, address executionTarget) external;
}
