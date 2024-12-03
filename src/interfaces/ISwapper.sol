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

    struct SwapOrder {
        DexAggregator aggregator;
        bytes data;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 minOutputAmount;
    }

    function dexAggregatorTargets(DexAggregator aggregator)
        external
        view
        returns (address approvalTarget, address executionTarget);

    function swap(SwapOrder calldata order) external returns (uint256);
}
