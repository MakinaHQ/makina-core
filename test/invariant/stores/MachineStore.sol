// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract MachineStore {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public totalBrigeFee;

    uint256 public totalAum;

    uint256 public spokeChainId;

    address[] public tokens;

    mapping(uint16 bridgeID => uint256 feeBps) public bridgeFeeBps;

    mapping(address token => uint256 transferId) public pendingMachineScheduledOutTransferId;
    mapping(address token => uint256 transferId) public pendingMachineSentOutTransferId;
    mapping(address token => uint256 transferId) public pendingMachineRefundedOutTransferId;
    EnumerableSet.UintSet private _pendingMachineReceivedInTransferIds;

    EnumerableSet.UintSet private _pendingCaliberScheduledOutTransferIds;
    EnumerableSet.UintSet private _pendingCaliberSentOutTransferIds;
    EnumerableSet.UintSet private _pendingCaliberRefundedOutTransferIds;
    mapping(address token => uint256 transferId) public pendingCaliberReceivedInTransferId;
    mapping(address token => uint256 transferId) public pendingCaliberClaimedInTransferId;

    mapping(uint256 machineOutTransferId => uint256 acrossV3TransferId) public machineAcrossV3TransferId;

    mapping(uint256 caliberOutTransferId => uint256 acrossV3TransferId) public caliberAcrossV3TransferId;

    mapping(uint256 machineInTransferId => address token) public machineInTransferToken;
    mapping(uint256 machineInTransferId => uint256 pendingFee) public pendingMachineInTransferBridgeFee;

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

    ///
    /// Transfer list getters
    ///

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

    ///
    /// Transfer list adding
    ///

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

    ///
    /// Transfer list removal
    ///

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

    ///
    /// Transfer data setters
    ///

    function setPendingMachineScheduledOutTransferId(address token, uint256 transferId) external {
        pendingMachineScheduledOutTransferId[token] = transferId;
    }

    function setPendingMachineSentOutTransferId(address token, uint256 transferId) external {
        pendingMachineSentOutTransferId[token] = transferId;
    }

    function setPendingMachineRefundedOutTransferId(address token, uint256 transferId) external {
        pendingMachineRefundedOutTransferId[token] = transferId;
    }

    function setPendingCaliberReceivedInTransferId(address token, uint256 transferId) external {
        pendingCaliberReceivedInTransferId[token] = transferId;
    }

    function setPendingCaliberClaimedInTransferId(address token, uint256 transferId) external {
        pendingCaliberClaimedInTransferId[token] = transferId;
    }

    function clearPendingMachineScheduledOutTransferId(address token) external {
        delete pendingMachineScheduledOutTransferId[token];
    }

    function clearPendingMachineSentOutTransferId(address token) external {
        delete pendingMachineSentOutTransferId[token];
    }

    function clearPendingMachineRefundedOutTransferId(address token) external {
        delete pendingMachineRefundedOutTransferId[token];
    }

    function clearPendingCaliberReceivedInTransferId(address token) external {
        delete pendingCaliberReceivedInTransferId[token];
    }

    function clearPendingCaliberClaimedInTransferId(address token) external {
        delete pendingCaliberClaimedInTransferId[token];
    }

    function setMachineAcrossV3TransferId(uint256 machineOutTransferId, uint256 acrossV3TransferId) external {
        machineAcrossV3TransferId[machineOutTransferId] = acrossV3TransferId;
    }

    function setCaliberAcrossV3TransferId(uint256 caliberOutTransferId, uint256 acrossV3TransferId) external {
        caliberAcrossV3TransferId[caliberOutTransferId] = acrossV3TransferId;
    }

    function setMachineInTransferToken(uint256 machineOutTransferId, address token) external {
        machineInTransferToken[machineOutTransferId] = token;
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

    function setBridgeFeeBps(uint16 bridgeID, uint256 feeBps) external {
        bridgeFeeBps[bridgeID] = feeBps;
    }
}
