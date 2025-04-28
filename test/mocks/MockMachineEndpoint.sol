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
    event SendOutBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId, bytes data);
    event AuthorizeInBridgeTransfer(IBridgeAdapter.Bridge bridgeId, bytes32 messageHash);
    event ClaimInBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId);
    event CancelOutBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId);

    function mechanic() public pure returns (address) {
        return address(0);
    }

    function securityCouncil() public pure returns (address) {
        return address(0);
    }

    function riskManager() public pure returns (address) {
        return address(0);
    }

    function riskManagerTimelock() public pure returns (address) {
        return address(0);
    }

    function recoveryMode() public pure returns (bool) {
        return false;
    }

    function setMechanic(address) external pure {
        return;
    }

    function setSecurityCouncil(address) external pure {
        return;
    }

    function setRiskManager(address) external pure {
        return;
    }

    function setRiskManagerTimelock(address) external pure {
        return;
    }

    function setRecoveryMode(bool) external pure {
        return;
    }

    function isBridgeSupported(IBridgeAdapter.Bridge) external pure returns (bool) {
        return false;
    }

    function getMaxBridgeLossBps(IBridgeAdapter.Bridge) external pure returns (uint256) {
        return 0;
    }

    function isOutTransferEnabled(IBridgeAdapter.Bridge) external pure returns (bool) {
        return false;
    }

    function getBridgeAdapter(IBridgeAdapter.Bridge) external pure returns (address) {
        return address(0);
    }

    function createBridgeAdapter(IBridgeAdapter.Bridge, uint256, bytes calldata) external pure returns (address) {
        return address(0);
    }

    function setMaxBridgeLossBps(IBridgeAdapter.Bridge, uint256) external pure {
        return;
    }

    function setOutTransferEnabled(IBridgeAdapter.Bridge, bool) external pure {
        return;
    }

    function sendOutBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId, bytes calldata data) external {
        emit SendOutBridgeTransfer(bridgeId, transferId, data);
    }

    function authorizeInBridgeTransfer(IBridgeAdapter.Bridge bridgeId, bytes32 messageHash) external {
        emit AuthorizeInBridgeTransfer(bridgeId, messageHash);
    }

    function claimInBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId) external {
        emit ClaimInBridgeTransfer(bridgeId, transferId);
    }

    function cancelOutBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId) external {
        emit CancelOutBridgeTransfer(bridgeId, transferId);
    }

    function resetBridgingState(address) external pure override {
        return;
    }

    function manageTransfer(address token, uint256 amount, bytes calldata data) external override {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit ManageTransfer(token, amount, data);
    }
}
