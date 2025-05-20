// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockERC20} from "./MockERC20.sol";

import {ICaliber} from "../../src/interfaces/ICaliber.sol";

/// @dev MockFlashLoanModule contract for testing use only
contract MockFlashLoanModule {
    using Math for uint256;
    using SafeERC20 for IERC20;

    error FlashLoanFailed();

    bool public reentrancyMode;

    function flashLoan(ICaliber.Instruction calldata instruction, address token, uint256 amount) external {
        uint256 balBefore = IERC20(token).balanceOf(address(this));

        IERC20(token).forceApprove(msg.sender, amount);

        if (reentrancyMode) {
            MockERC20(token).scheduleReenter(
                MockERC20.Type.Before,
                address(this),
                abi.encodeCall(this.reentrancy, (msg.sender, instruction, token, amount))
            );
        }

        (bool success, bytes memory returnData) =
            msg.sender.call(abi.encodeCall(ICaliber.manageFlashLoan, (instruction, token, amount)));

        if (!success) {
            revert(string(returnData));
        }

        if (IERC20(token).balanceOf(address(this)) < balBefore) {
            revert FlashLoanFailed();
        }
    }

    function reentrancy(address caliber, ICaliber.Instruction calldata instruction, address token, uint256 amount)
        external
    {
        ICaliber(caliber).manageFlashLoan(instruction, token, amount);
    }

    function setReentrancyMode(bool mode) external {
        reentrancyMode = mode;
    }
}
