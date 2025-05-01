// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Vm} from "forge-std/Vm.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";

import {IHubRegistry} from "src/interfaces/IHubRegistry.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IChainRegistry} from "src/interfaces/IChainRegistry.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {CaliberMailbox} from "src/caliber/CaliberMailbox.sol";
import {Machine} from "src/machine/Machine.sol";
import {MachineStore} from "../stores/MachineStore.sol";
import {IMockAcrossV3SpokePool} from "../../mocks/IMockAcrossV3SpokePool.sol";
import {PerChainData} from "../../utils/WormholeQueryTestHelpers.sol";
import {WormholeQueryTestHelpers} from "../../utils/WormholeQueryTestHelpers.sol";

contract MachineHandler is CommonBase, StdCheats, StdUtils {
    Machine public machine;
    Caliber public hubCaliber;
    Caliber public spokeCaliber;
    CaliberMailbox public spokeCaliberMailbox;
    MachineStore public machineStore;

    constructor(Machine _machine, Caliber _spokeCaliber, MachineStore _machineStore) {
        machine = _machine;
        hubCaliber = Caliber(_machine.hubCaliber());
        spokeCaliber = _spokeCaliber;
        spokeCaliberMailbox = CaliberMailbox(_spokeCaliber.hubMachineEndpoint());
        machineStore = _machineStore;
    }

    ///
    /// Machine Side
    ///

    /// @dev Schedules a transfer from machine to spoke caliber
    function machine_transferToSpokeCaliber_AccrossV3(uint256 tokenIndex, uint256 amount) external {
        tokenIndex = _bound(tokenIndex, 0, machineStore.tokensLength() - 1);
        address token = machineStore.tokens(tokenIndex);
        amount = _bound(amount, 0, IERC20(token).balanceOf(address(machine)));
        if (amount == 0) {
            return;
        }

        vm.startPrank(_mechanic());

        address bridgeAdapter = machine.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
        uint256 transferId = IBridgeAdapter(bridgeAdapter).nextOutTransferId();

        vm.recordLogs();
        machine.transferToSpokeCaliber(
            IBridgeAdapter.Bridge.ACROSS_V3,
            machineStore.spokeChainId(),
            token,
            amount,
            _applyBridgeFee(IBridgeAdapter.Bridge.ACROSS_V3, amount)
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // 2nd topic of 3rd emitted event
        bytes32 messageHash = entries[2].topics[2];

        spokeCaliberMailbox.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, messageHash);

        vm.stopPrank();

        machineStore.addPendingMachineScheduledOutTransferId(transferId);
    }

    /// @dev Sends a scheduled outgoing transfer from machine to spoke caliber
    function machine_sendOutBridgeTransfer_AccrossV3(uint256 transferIndex) external {
        uint256 transfersLen = machineStore.pendingMachineScheduledOutTransferLength();
        if (transfersLen == 0) {
            return;
        }
        transferIndex = _bound(transferIndex, 0, transfersLen - 1);
        uint256 transferId = machineStore.getPendingMachineScheduledOutTransferId(transferIndex);
        address bridgeAdapter = machine.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
        uint256 acrossV3TransferId =
            IMockAcrossV3SpokePool(IBridgeAdapter(bridgeAdapter).executionTarget()).numberOfDeposits();

        vm.prank(_mechanic());
        machine.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId, abi.encode(1 weeks));

        machineStore.removePendingMachineScheduledOutTransferId(transferId);
        machineStore.addPendingMachineSentOutTransferId(transferId);
        machineStore.setMachineAcrossV3TransferId(transferId, acrossV3TransferId);
    }

    /// @dev Cancels a refunded transfer initially sent from machine to spoke caliber
    function machine_cancelOutBridgeTransfer_AccrossV3(uint256 transferIndex) external {
        uint256 transfersLen = machineStore.pendingMachineRefundedOutTransferLength();
        if (transfersLen == 0) {
            return;
        }
        transferIndex = _bound(transferIndex, 0, transfersLen - 1);
        uint256 transferId = machineStore.getPendingMachineRefundedOutTransferId(transferIndex);

        vm.prank(_mechanic());
        machine.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        machineStore.removePendingMachineRefundedOutTransferId(transferId);
    }

    /// @dev Claims a pending transfer received by machine from spoke caliber
    function machine_claimInBridgeTransfer_AccrossV3(uint256 transferIndex) external {
        uint256 transfersLen = machineStore.pendingMachineReceivedInTransferLength();
        if (transfersLen == 0) {
            return;
        }
        transferIndex = _bound(transferIndex, 0, transfersLen - 1);
        uint256 transferId = machineStore.getPendingMachineReceivedInTransferId(transferIndex);

        vm.prank(_mechanic());
        machine.claimInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        machineStore.removePendingMachineReceivedInTransferId(transferId);
        machineStore.addTotalAccountedBridgeFee(
            machineStore.machineInTransferToken(transferId), machineStore.pendingMachineInTransferBridgeFee(transferId)
        );
    }

    ///
    /// Caliber Side
    ///

    /// @dev Schedules a transfer from spoke caliber to machine
    function caliber_transferToHubMachine_AccrossV3(uint256 tokenIndex, uint256 amount) external {
        tokenIndex = _bound(tokenIndex, 0, machineStore.tokensLength() - 1);
        address token = machineStore.tokens(tokenIndex);
        amount = _bound(amount, 0, IERC20(token).balanceOf(address(spokeCaliber)));
        if (amount == 0) {
            return;
        }

        vm.startPrank(_mechanic());

        address bridgeAdapter = spokeCaliberMailbox.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
        uint256 transferId = IBridgeAdapter(bridgeAdapter).nextOutTransferId();

        vm.recordLogs();
        spokeCaliber.transferToHubMachine(
            token,
            amount,
            abi.encode(IBridgeAdapter.Bridge.ACROSS_V3, _applyBridgeFee(IBridgeAdapter.Bridge.ACROSS_V3, amount))
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // 2nd topic of 5th emitted event
        bytes32 messageHash = entries[4].topics[2];

        machine.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, messageHash);

        vm.stopPrank();

        machineStore.addPendingCaliberScheduledOutTransferId(transferId);
    }

    /// @dev Sends a scheduled outgoing transfer from spoke caliber to machine
    function caliber_sendOutBridgeTransfer_AccrossV3(uint256 transferIndex) external {
        uint256 transfersLen = machineStore.pendingCaliberScheduledOutTransferLength();
        if (transfersLen == 0) {
            return;
        }
        transferIndex = _bound(transferIndex, 0, transfersLen - 1);
        uint256 transferId = machineStore.getPendingCaliberScheduledOutTransferId(transferIndex);
        address bridgeAdapter = spokeCaliberMailbox.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
        uint256 acrossV3TransferId =
            IMockAcrossV3SpokePool(IBridgeAdapter(bridgeAdapter).executionTarget()).numberOfDeposits();

        vm.prank(_mechanic());
        spokeCaliberMailbox.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId, abi.encode(1 weeks));

        machineStore.removePendingCaliberScheduledOutTransferId(transferId);
        machineStore.addPendingCaliberSentOutTransferId(transferId);
        machineStore.setCaliberAcrossV3TransferId(transferId, acrossV3TransferId);

        notifySpokeCaliberAccounting();
    }

    /// @dev Cancels a refunded transfer initially sent from spoke caliber to machine
    function caliber_cancelOutBridgeTransfer_AccrossV3(uint256 transferIndex) external {
        uint256 transfersLen = machineStore.pendingCaliberRefundedOutTransferLength();
        if (transfersLen == 0) {
            return;
        }
        transferIndex = _bound(transferIndex, 0, transfersLen - 1);
        uint256 transferId = machineStore.getPendingCaliberRefundedOutTransferId(transferIndex);

        vm.prank(_mechanic());
        spokeCaliberMailbox.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        machineStore.removePendingCaliberRefundedOutTransferId(transferId);
    }

    /// @dev Claims a pending transfer received by spoke caliber from machine
    function caliber_claimInBridgeTransfer_AccrossV3(uint256 transferIndex) external {
        uint256 transfersLen = machineStore.pendingCaliberReceivedInTransferLength();
        if (transfersLen == 0) {
            return;
        }
        transferIndex = _bound(transferIndex, 0, transfersLen - 1);
        uint256 transferId = machineStore.getPendingCaliberReceivedInTransferId(transferIndex);

        vm.prank(_mechanic());
        spokeCaliberMailbox.claimInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        machineStore.removePendingCaliberReceivedInTransferId(transferId);
        machineStore.addPendingCaliberRealisedBridgeFee(
            machineStore.caliberInTransferToken(transferId), machineStore.pendingCaliberInTransferBridgeFee(transferId)
        );
    }

    ///
    /// ACROSS V3 Side
    ///

    /// @dev Cancels a pending accross V3 transfer and refund the tokens to the sender
    function acrossV3CancelTransfer(bool fromMachineToCaliber, uint256 transferIndex) external {
        if (fromMachineToCaliber) {
            uint256 transfersLen = machineStore.pendingMachineSentOutTransferLength();
            if (transfersLen == 0) {
                return;
            }
            transferIndex = _bound(transferIndex, 0, transfersLen - 1);
            uint256 transferId = machineStore.getPendingMachineSentOutTransferId(transferIndex);
            uint256 acrossV3TransferId = machineStore.machineAcrossV3TransferId(transferId);
            address bridgeAdapter = machine.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);

            IMockAcrossV3SpokePool(IBridgeAdapter(bridgeAdapter).executionTarget()).cancelTransfer(acrossV3TransferId);

            machineStore.removePendingMachineSentOutTransferId(transferId);
            machineStore.addPendingMachineRefundedOutTransferId(transferId);
        } else {
            uint256 transfersLen = machineStore.pendingCaliberSentOutTransferLength();
            if (transfersLen == 0) {
                return;
            }
            transferIndex = _bound(transferIndex, 0, transfersLen - 1);
            uint256 transferId = machineStore.getPendingCaliberSentOutTransferId(transferIndex);
            uint256 acrossV3TransferId = machineStore.caliberAcrossV3TransferId(transferId);
            address bridgeAdapter = spokeCaliberMailbox.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);

            IMockAcrossV3SpokePool(IBridgeAdapter(bridgeAdapter).executionTarget()).cancelTransfer(acrossV3TransferId);

            machineStore.removePendingCaliberSentOutTransferId(transferId);
            machineStore.addPendingCaliberRefundedOutTransferId(transferId);
        }
    }

    /// @dev Settles a pending accross V3 transfer
    function acrossV3SettleTransfer(bool fromMachineToCaliber, uint256 transferIndex) external {
        if (fromMachineToCaliber) {
            uint256 transfersLen = machineStore.pendingMachineSentOutTransferLength();
            if (transfersLen == 0) {
                return;
            }
            transferIndex = _bound(transferIndex, 0, transfersLen - 1);
            uint256 transferId = machineStore.getPendingMachineSentOutTransferId(transferIndex);
            uint256 acrossV3TransferId = machineStore.machineAcrossV3TransferId(transferId);

            address receiverBridgeAdapter = spokeCaliberMailbox.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
            uint256 inTransferId = IBridgeAdapter(receiverBridgeAdapter).nextInTransferId();

            address acrossV3SpokePool = IBridgeAdapter(receiverBridgeAdapter).executionTarget();

            IMockAcrossV3SpokePool.DepositV3Params memory depositV3Params =
                IMockAcrossV3SpokePool(acrossV3SpokePool).getTransferData(acrossV3TransferId);
            IMockAcrossV3SpokePool(acrossV3SpokePool).settleTransfer(acrossV3TransferId);

            machineStore.removePendingMachineSentOutTransferId(transferId);
            machineStore.addPendingCaliberReceivedInTransferId(inTransferId);
            machineStore.setCaliberInTransferToken(inTransferId, address(uint160(uint256(depositV3Params.outputToken))));
            machineStore.setPendingCaliberInTransferBridgeFee(
                inTransferId, depositV3Params.inputAmount - depositV3Params.outputAmount
            );
        } else {
            uint256 transfersLen = machineStore.pendingCaliberSentOutTransferLength();
            if (transfersLen == 0) {
                return;
            }
            transferIndex = _bound(transferIndex, 0, transfersLen - 1);
            uint256 transferId = machineStore.getPendingCaliberSentOutTransferId(transferIndex);
            uint256 acrossV3TransferId = machineStore.caliberAcrossV3TransferId(transferId);

            address receiverBridgeAdapter = machine.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
            uint256 inTransferId = IBridgeAdapter(receiverBridgeAdapter).nextInTransferId();

            address acrossV3SpokePool = IBridgeAdapter(receiverBridgeAdapter).executionTarget();

            IMockAcrossV3SpokePool.DepositV3Params memory depositV3Params =
                IMockAcrossV3SpokePool(acrossV3SpokePool).getTransferData(acrossV3TransferId);
            IMockAcrossV3SpokePool(acrossV3SpokePool).settleTransfer(acrossV3TransferId);

            machineStore.removePendingCaliberSentOutTransferId(transferId);
            machineStore.addPendingMachineReceivedInTransferId(inTransferId);
            machineStore.setMachineInTransferToken(inTransferId, address(uint160(uint256(depositV3Params.outputToken))));
            machineStore.setPendingMachineInTransferBridgeFee(
                inTransferId, depositV3Params.inputAmount - depositV3Params.outputAmount
            );
        }
    }

    /// @dev Notifies machine of the current state of the spoke caliber accounting
    function notifySpokeCaliberAccounting() public {
        uint16 whChainId =
            IChainRegistry(IHubRegistry(machine.registry()).chainRegistry()).evmToWhChainId(machineStore.spokeChainId());

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            spokeCaliberMailbox.getSpokeCaliberAccountingData();

        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            whChainId,
            uint64(block.number),
            uint64(block.timestamp),
            address(spokeCaliberMailbox),
            abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        for (uint256 i = 0; i < machineStore.tokensLength(); i++) {
            address token = machineStore.tokens(i);
            machineStore.addTotalAccountedBridgeFee(token, machineStore.pendingCaliberRealisedBridgeFee(token));
            machineStore.resetPendingCaliberRealisedBridgeFee(token);
        }
    }

    function _mechanic() internal view returns (address) {
        return machine.mechanic();
    }

    function _applyBridgeFee(IBridgeAdapter.Bridge bridgeId, uint256 amount) internal view returns (uint256) {
        return (amount * (10_000 - machineStore.bridgeFeeBps(bridgeId))) / 10_000;
    }
}
