// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapModule} from "../interfaces/ISwapModule.sol";

contract SwapModule is AccessManagedUpgradeable, ISwapModule {
    using SafeERC20 for IERC20;

    /// @inheritdoc ISwapModule
    mapping(Swapper swapper => SwapperTargets targets) public swapperTargets;

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc ISwapModule
    function swap(SwapOrder calldata order) external override returns (uint256) {
        SwapperTargets storage targets = swapperTargets[order.swapper];
        if (targets.approvalTarget == address(0) || targets.executionTarget == address(0)) {
            revert SwapperNotSet();
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

        emit Swapped(caller, order.swapper, order.inputToken, order.outputToken, order.inputAmount, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc ISwapModule
    function setSwapperTargets(Swapper swapper, address approvalTarget, address executionTarget)
        external
        override
        restricted
    {
        swapperTargets[swapper] = SwapperTargets(approvalTarget, executionTarget);
        emit SwapperTargetsSet(swapper, approvalTarget, executionTarget);
    }
}
