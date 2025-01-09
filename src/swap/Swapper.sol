// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";

contract Swapper is AccessManagedUpgradeable, ISwapper {
    using SafeERC20 for IERC20;

    /// @inheritdoc ISwapper
    mapping(DexAggregator aggregator => DexAggregatorTargets targets) public dexAggregatorTargets;

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc ISwapper
    function swap(SwapOrder calldata order) external override returns (uint256) {
        DexAggregatorTargets storage targets = dexAggregatorTargets[order.aggregator];
        if (targets.approvalTarget == address(0) || targets.executionTarget == address(0)) {
            revert DexAggregatorNotSet();
        }

        address caller = msg.sender;
        IERC20(order.inputToken).safeTransferFrom(caller, address(this), order.inputAmount);

        uint256 balBefore = IERC20(order.outputToken).balanceOf(address(this));

        IERC20(order.inputToken).forceApprove(targets.approvalTarget, order.inputAmount);
        // solhint-disable-next-line
        (bool success,) = targets.executionTarget.call(order.data);
        if (!success) {
            revert SwapFailed();
        }
        IERC20(order.inputToken).forceApprove(targets.approvalTarget, 0);

        uint256 outputAmount = IERC20(order.outputToken).balanceOf(address(this)) - balBefore;

        if (outputAmount < order.minOutputAmount) {
            revert AmountOutTooLow();
        }
        IERC20(order.outputToken).safeTransfer(caller, outputAmount);

        emit Swapped(caller, order.aggregator, order.inputToken, order.outputToken, order.inputAmount, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc ISwapper
    function setDexAggregatorTargets(DexAggregator aggregator, address approvalTarget, address executionTarget)
        external
        override
        restricted
    {
        dexAggregatorTargets[aggregator] = DexAggregatorTargets(approvalTarget, executionTarget);
        emit DexAggregatorTargetsSet(aggregator, approvalTarget, executionTarget);
    }
}
