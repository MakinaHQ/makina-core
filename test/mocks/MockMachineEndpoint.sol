// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IMachineEndpoint} from "src/interfaces/IMachineEndpoint.sol";

/// @dev MockMachineEndpoint contract for testing use only
/// @dev This contract facilitates testing of interactions with a IMachineEndpoint instance.
contract MockMachineEndpoint is IMachineEndpoint {
    using SafeERC20 for IERC20;

    event ManageTransfer(address token, uint256 amount, bytes data);

    function manageTransfer(address token, uint256 amount, bytes calldata data) external override {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit ManageTransfer(token, amount, data);
    }

    function isBridgeSupported(IBridgeAdapter.Bridge) external pure returns (bool) {
        return false;
    }

    function getBridgeAdapter(IBridgeAdapter.Bridge) external pure returns (address) {
        return address(0);
    }

    function createBridgeAdapter(IBridgeAdapter.Bridge, bytes calldata) external pure returns (address) {
        return address(0);
    }
}
