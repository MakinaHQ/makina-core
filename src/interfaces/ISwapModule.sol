// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ISwapModule {
    error AmountOutTooLow();
    error SwapperNotSet();
    error SwapFailed();

    event SwapperTargetsSet(Swapper indexed swapper, address approvalTarget, address executionTarget);
    event Swapped(
        address indexed sender,
        Swapper swapper,
        address indexed inputToken,
        address indexed outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    );

    enum Swapper {
        ZEROX,
        ODOS,
        ONE_INCH,
        KYBERSWAP
    }

    struct SwapperTargets {
        address approvalTarget;
        address executionTarget;
    }

    /// @notice Swap order object.
    /// @param swapper The external swap protocol.
    /// @param data The swap calldata to pass to the swapper's execution target.
    /// @param inputToken The input token.
    /// @param outputToken The output token.
    /// @param inputAmount The input amount.
    /// @param minOutputAmount The minimum expected output amount.
    struct SwapOrder {
        Swapper swapper;
        bytes data;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 minOutputAmount;
    }

    /// @notice Returns approval and execution targets for a given swapper.
    /// @param swapper The swapper ID.
    /// @return approvalTarget The approval target.
    /// @return executionTarget The execution target.
    function swapperTargets(Swapper swapper) external view returns (address approvalTarget, address executionTarget);

    /// @notice Swaps tokens using a given swapper.
    /// @param order The swap order object.
    function swap(SwapOrder calldata order) external returns (uint256);

    /// @notice Sets approval and execution targets for a given swapper.
    /// @param swapper The swapper ID.
    /// @param approvalTarget The approval target.
    function setSwapperTargets(Swapper swapper, address approvalTarget, address executionTarget) external;
}
