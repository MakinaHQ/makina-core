// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

contract MachineStore {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public totalBrigeFee;

    uint256 public totalAum;

    uint256 public spokeChainId;

    address[] public tokens;

    mapping(IBridgeAdapter.Bridge bridgeID => uint256 feeBps) public bridgeFeeBps;

    EnumerableSet.UintSet private _pendingMachineScheduledOutTransferIds;
    EnumerableSet.UintSet private _pendingMachineSentOutTransferIds;
    EnumerableSet.UintSet private _pendingMachineRefundedOutTransferIds;
    EnumerableSet.UintSet private _pendingMachineReceivedInTransferIds;

    EnumerableSet.UintSet private _pendingCaliberScheduledOutTransferIds;
    EnumerableSet.UintSet private _pendingCaliberSentOutTransferIds;
    EnumerableSet.UintSet private _pendingCaliberRefundedOutTransferIds;
    EnumerableSet.UintSet private _pendingCaliberReceivedInTransferIds;

    mapping(uint256 machineOutTransferId => uint256 acrossV3TransferId) public machineAcrossV3TransferId;

    mapping(uint256 caliberOutTransferId => uint256 acrossV3TransferId) public caliberAcrossV3TransferId;

    mapping(uint256 machineInTransferId => address token) public machineInTransferToken;
    mapping(uint256 machineInTransferId => uint256 pendingFee) public pendingMachineInTransferBridgeFee;

    mapping(uint256 caliberInTransferId => address token) public caliberInTransferToken;
    mapping(uint256 caliberInTransferId => uint256 pendingFee) public pendingCaliberInTransferBridgeFee;
    mapping(address token => uint256 totalRealisedFee) public pendingCaliberRealisedBridgeFee;

    mapping(address token => uint256 totalAccountedFee) public totalAccountedBridgeFee;

    ///
    /// Misc data getters
    ///

    function tokensLength() external view returns (uint256) {
        return tokens.length;
    }

    ///
    /// Transfer list lengths
    ///

    function pendingMachineScheduledOutTransferLength() external view returns (uint256) {
        return _pendingMachineScheduledOutTransferIds.length();
    }

    function pendingMachineSentOutTransferLength() external view returns (uint256) {
        return _pendingMachineSentOutTransferIds.length();
    }

    function pendingMachineRefundedOutTransferLength() external view returns (uint256) {
        return _pendingMachineRefundedOutTransferIds.length();
    }

    function pendingMachineReceivedInTransferLength() external view returns (uint256) {
        return _pendingMachineReceivedInTransferIds.length();
    }

    function pendingCaliberScheduledOutTransferLength() external view returns (uint256) {
        return _pendingCaliberScheduledOutTransferIds.length();
    }

    function pendingCaliberSentOutTransferLength() external view returns (uint256) {
        return _pendingCaliberSentOutTransferIds.length();
    }

    function pendingCaliberRefundedOutTransferLength() external view returns (uint256) {
        return _pendingCaliberRefundedOutTransferIds.length();
    }

    function pendingCaliberReceivedInTransferLength() external view returns (uint256) {
        return _pendingCaliberReceivedInTransferIds.length();
    }

    ///
    /// Transfer list getters
    ///

    function getPendingMachineScheduledOutTransferId(uint256 index) external view returns (uint256) {
        return _pendingMachineScheduledOutTransferIds.at(index);
    }

    function getPendingMachineSentOutTransferId(uint256 index) external view returns (uint256) {
        return _pendingMachineSentOutTransferIds.at(index);
    }

    function getPendingMachineRefundedOutTransferId(uint256 index) external view returns (uint256) {
        return _pendingMachineRefundedOutTransferIds.at(index);
    }

    function getPendingMachineReceivedInTransferId(uint256 index) external view returns (uint256) {
        return _pendingMachineReceivedInTransferIds.at(index);
    }

    function getPendingCaliberScheduledOutTransferId(uint256 index) external view returns (uint256) {
        return _pendingCaliberScheduledOutTransferIds.at(index);
    }

    function getPendingCaliberSentOutTransferId(uint256 index) external view returns (uint256) {
        return _pendingCaliberSentOutTransferIds.at(index);
    }

    function getPendingCaliberRefundedOutTransferId(uint256 index) external view returns (uint256) {
        return _pendingCaliberRefundedOutTransferIds.at(index);
    }

    function getPendingCaliberReceivedInTransferId(uint256 index) external view returns (uint256) {
        return _pendingCaliberReceivedInTransferIds.at(index);
    }

    ///
    /// Transfer list adding
    ///

    function addPendingMachineScheduledOutTransferId(uint256 transferId) external {
        _pendingMachineScheduledOutTransferIds.add(transferId);
    }

    function addPendingMachineSentOutTransferId(uint256 transferId) external {
        _pendingMachineSentOutTransferIds.add(transferId);
    }

    function addPendingMachineRefundedOutTransferId(uint256 transferId) external {
        _pendingMachineRefundedOutTransferIds.add(transferId);
    }

    function addPendingMachineReceivedInTransferId(uint256 transferId) external {
        _pendingMachineReceivedInTransferIds.add(transferId);
    }

    function addPendingCaliberScheduledOutTransferId(uint256 transferId) external {
        _pendingCaliberScheduledOutTransferIds.add(transferId);
    }

    function addPendingCaliberSentOutTransferId(uint256 transferId) external {
        _pendingCaliberSentOutTransferIds.add(transferId);
    }

    function addPendingCaliberRefundedOutTransferId(uint256 transferId) external {
        _pendingCaliberRefundedOutTransferIds.add(transferId);
    }

    function addPendingCaliberReceivedInTransferId(uint256 transferId) external {
        _pendingCaliberReceivedInTransferIds.add(transferId);
    }

    ///
    /// Transfer list removal
    ///

    function removePendingMachineScheduledOutTransferId(uint256 transferId) external {
        _pendingMachineScheduledOutTransferIds.remove(transferId);
    }

    function removePendingMachineSentOutTransferId(uint256 transferId) external {
        _pendingMachineSentOutTransferIds.remove(transferId);
    }

    function removePendingMachineRefundedOutTransferId(uint256 transferId) external {
        _pendingMachineRefundedOutTransferIds.remove(transferId);
    }

    function removePendingMachineReceivedInTransferId(uint256 transferId) external {
        _pendingMachineReceivedInTransferIds.remove(transferId);
    }

    function removePendingCaliberScheduledOutTransferId(uint256 transferId) external {
        _pendingCaliberScheduledOutTransferIds.remove(transferId);
    }

    function removePendingCaliberSentOutTransferId(uint256 transferId) external {
        _pendingCaliberSentOutTransferIds.remove(transferId);
    }

    function removePendingCaliberRefundedOutTransferId(uint256 transferId) external {
        _pendingCaliberRefundedOutTransferIds.remove(transferId);
    }

    function removePendingCaliberReceivedInTransferId(uint256 transferId) external {
        _pendingCaliberReceivedInTransferIds.remove(transferId);
    }

    ///
    /// Transfer data setters
    ///

    function setMachineAcrossV3TransferId(uint256 machineOutTransferId, uint256 acrossV3TransferId) external {
        machineAcrossV3TransferId[machineOutTransferId] = acrossV3TransferId;
    }

    function setCaliberAcrossV3TransferId(uint256 caliberOutTransferId, uint256 acrossV3TransferId) external {
        caliberAcrossV3TransferId[caliberOutTransferId] = acrossV3TransferId;
    }

    function setMachineInTransferToken(uint256 machineOutTransferId, address token) external {
        machineInTransferToken[machineOutTransferId] = token;
    }

    function setCaliberInTransferToken(uint256 caliberOutTransferId, address token) external {
        caliberInTransferToken[caliberOutTransferId] = token;
    }

    function setPendingMachineInTransferBridgeFee(uint256 machineInTransferId, uint256 pendingFee) external {
        pendingMachineInTransferBridgeFee[machineInTransferId] = pendingFee;
    }

    function setPendingCaliberInTransferBridgeFee(uint256 caliberInTransferId, uint256 pendingFee) external {
        pendingCaliberInTransferBridgeFee[caliberInTransferId] = pendingFee;
    }

    function addPendingCaliberRealisedBridgeFee(address token, uint256 realisedFee) external {
        pendingCaliberRealisedBridgeFee[token] += realisedFee;
    }

    function resetPendingCaliberRealisedBridgeFee(address token) external {
        pendingCaliberRealisedBridgeFee[token] = 0;
    }

    function addTotalAccountedBridgeFee(address token, uint256 accountedFee) external {
        totalAccountedBridgeFee[token] += accountedFee;
    }

    ///
    /// Misc data setters
    ///

    function addToken(address token) external {
        tokens.push(token);
    }

    function setSpokeChainId(uint256 _spokeChainId) external {
        spokeChainId = _spokeChainId;
    }

    function setBridgeFeeBps(IBridgeAdapter.Bridge bridgeID, uint256 feeBps) external {
        bridgeFeeBps[bridgeID] = feeBps;
    }
}
