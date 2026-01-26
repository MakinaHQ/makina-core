// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMachineEndpoint} from "../../src/interfaces/IMachineEndpoint.sol";

/// @dev MockMachineEndpoint contract for testing use only
/// @dev This contract facilitates testing of interactions with a IMachineEndpoint instance.
contract MockMachineEndpoint is IMachineEndpoint {
    using SafeERC20 for IERC20;

    mapping(uint16 bridgeId => uint256 maxBridgeLossBps) private _maxBridgeLossBps;

    event ManageTransfer(address token, uint256 amount, bytes data);
    event OutBridgeTransferSent(uint16 bridgeId, uint256 transferId, bytes data);
    event InBridgeTransferAuthorized(uint16 bridgeId, bytes32 messageHash);
    event InBridgeTransferClaimed(uint16 bridgeId, uint256 transferId);
    event OutBridgeTransferCancelled(uint16 bridgeId, uint256 transferId);

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

    function restrictedAccountingMode() external pure returns (bool) {
        return false;
    }

    function isAccountingAgent(address) external pure returns (bool) {
        return false;
    }

    function isOperator(address) external pure returns (bool) {
        return false;
    }

    function isAccountingAuthorized(address) external pure returns (bool) {
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

    function setRestrictedAccountingMode(bool) external pure {
        return;
    }

    function addAccountingAgent(address) external pure {
        return;
    }

    function removeAccountingAgent(address) external pure {
        return;
    }

    function isBridgeSupported(uint16) external pure returns (bool) {
        return false;
    }

    function getMaxBridgeLossBps(uint16 bridgeId) external view returns (uint256) {
        return _maxBridgeLossBps[bridgeId];
    }

    function isOutTransferEnabled(uint16) external pure returns (bool) {
        return false;
    }

    function getBridgeAdapter(uint16) external pure returns (address) {
        return address(0);
    }

    function createBridgeAdapter(uint16, uint256, bytes calldata) external pure returns (address) {
        return address(0);
    }

    function setMaxBridgeLossBps(uint16 bridgeId, uint256 newMaxBridgeLossBps) external {
        _maxBridgeLossBps[bridgeId] = newMaxBridgeLossBps;
    }

    function setOutTransferEnabled(uint16, bool) external pure {
        return;
    }

    function sendOutBridgeTransfer(uint16 bridgeId, uint256 transferId, bytes calldata data) external {
        emit OutBridgeTransferSent(bridgeId, transferId, data);
    }

    function authorizeInBridgeTransfer(uint16 bridgeId, bytes32 messageHash) external {
        emit InBridgeTransferAuthorized(bridgeId, messageHash);
    }

    function claimInBridgeTransfer(uint16 bridgeId, uint256 transferId) external {
        emit InBridgeTransferClaimed(bridgeId, transferId);
    }

    function cancelOutBridgeTransfer(uint16 bridgeId, uint256 transferId) external {
        emit OutBridgeTransferCancelled(bridgeId, transferId);
    }

    function resetBridgingState(address) external pure override {
        return;
    }

    function manageTransfer(address token, uint256 amount, bytes calldata data) external override {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit ManageTransfer(token, amount, data);
    }
}
