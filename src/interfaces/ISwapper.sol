// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

interface ISwapper {
    error AmountOutTooLow();
    error DexAggregatorNotSet();
    error SwapFailed();

    event DexAggregatorTargetsSet(DexAggregator indexed aggregator, address approvalTarget, address executionTarget);
    event Swapped(
        address indexed sender,
        DexAggregator aggregator,
        address indexed inputToken,
        address indexed outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    );

    enum DexAggregator {
        ZEROX,
        ODOS,
        ONE_INCH,
        KYBERSWAP
    }

    struct DexAggregatorTargets {
        address approvalTarget;
        address executionTarget;
    }

    /// @notice Swap order object.
    /// @param aggregator The DEX aggregator.
    /// @param data The swap calldata to pass to the DEX aggregator's execution target.
    /// @param inputToken The input token.
    /// @param outputToken The output token.
    /// @param inputAmount The input amount.
    /// @param minOutputAmount The minimum expected output amount.
    struct SwapOrder {
        DexAggregator aggregator;
        bytes data;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 minOutputAmount;
    }

    /// @notice Returns approval and execution targets for a given DEX aggregator.
    /// @param aggregator The DEX aggregator.
    /// @return approvalTarget The approval target.
    /// @return executionTarget The execution target.
    function dexAggregatorTargets(DexAggregator aggregator)
        external
        view
        returns (address approvalTarget, address executionTarget);

    /// @notice Swaps tokens using a given DEX aggregator.
    /// @param order The swap order object.
    function swap(SwapOrder calldata order) external returns (uint256);

    /// @notice Sets approval and execution targets for a given DEX aggregator.
    /// @param aggregator The DEX aggregator.
    /// @param approvalTarget The approval target.
    function setDexAggregatorTargets(DexAggregator aggregator, address approvalTarget, address executionTarget)
        external;
}
