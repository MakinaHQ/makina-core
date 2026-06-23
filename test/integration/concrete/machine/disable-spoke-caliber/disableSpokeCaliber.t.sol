// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract DisableSpokeCaliber_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter internal bridgeAdapter;

    function setUp() public virtual override {
        Machine_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        bridgeAdapter = IBridgeAdapter(
            hubCoreFactory.createBridgeAdapter(
                address(machine),
                IBridgeAdapterFactory.BridgeAdapterInitParams(ACROSS_V3_BRIDGE_ID, "", DEFAULT_MAX_BRIDGE_LOSS_BPS)
            )
        );
        vm.stopPrank();
    }

    function test_RevertWhen_ReentrantCall() public {
        accountingToken.scheduleReenter(
            MockERC20.Type.Before, address(machine), abi.encodeCall(IMachine.disableSpokeCaliber, (0))
        );

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(address(caliber));
        machine.manageTransfer(address(accountingToken), 0, "");
    }

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.disableSpokeCaliber(0);
    }

    function test_RevertWhen_InvalidChainId() public {
        vm.expectRevert(Errors.InvalidChainId.selector);
        vm.prank(dao);
        machine.disableSpokeCaliber(SPOKE_CHAIN_ID);
    }

    function test_RevertWhen_CaliberAlreadyDisabled() public {
        vm.startPrank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, address(spokeCaliberMailboxAddr), new uint16[](0), new address[](0));
        machine.disableSpokeCaliber(SPOKE_CHAIN_ID);

        vm.expectRevert(Errors.AlreadyDisabled.selector);
        machine.disableSpokeCaliber(SPOKE_CHAIN_ID);
    }

    function test_RevertWhen_CaliberNotEmpty() public {
        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, address(spokeCaliberMailboxAddr), new uint16[](0), new address[](0));

        uint256 blockNum = 1e10;
        uint256 blockTime = block.timestamp;
        bytes memory report = _buildSpokeCaliberAccountingReportWithTransfers(
            SPOKE_CHAIN_ID, blockNum, blockTime, false, 1, new bytes[](0), new bytes[](0)
        );
        creForwarder.forwardReport(address(machine), report, DEFAULT_CRE_WORKFLOW_ID);

        vm.expectRevert(Errors.CaliberNotEmpty.selector);
        vm.prank(dao);
        machine.disableSpokeCaliber(SPOKE_CHAIN_ID);
    }

    function test_RevertWhen_PendingBridgeTransfer() public {
        vm.startPrank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr);
        vm.stopPrank();

        // initiate a Hub -> Spoke transfer
        uint256 inputAmount = 1;
        deal(address(accountingToken), address(machine), inputAmount, true);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, inputAmount
        );

        // 1 pending Hub -> Spoke transfer
        vm.expectRevert(Errors.PendingBridgeTransfer.selector);
        vm.prank(dao);
        machine.disableSpokeCaliber(SPOKE_CHAIN_ID);

        // simulate a pending Spoke -> Hub transfer
        uint256 blockNum = 1e10;
        uint256 blockTime = block.timestamp;
        bytes[] memory cBridgeIn = new bytes[](1);
        cBridgeIn[0] = abi.encode(spokeAccountingTokenAddr, inputAmount);
        bytes[] memory cBridgeOut = new bytes[](1);
        cBridgeOut[0] = abi.encode(spokeBaseTokenAddr, inputAmount);
        bytes memory report = _buildSpokeCaliberAccountingReportWithTransfers(
            SPOKE_CHAIN_ID, blockNum, blockTime, true, 0, cBridgeIn, cBridgeOut
        );
        creForwarder.forwardReport(address(machine), report, DEFAULT_CRE_WORKFLOW_ID);

        // 1 complete Hub -> Spoke transfer + 1 pending Spoke -> Hub transfer
        vm.expectRevert(Errors.PendingBridgeTransfer.selector);
        vm.prank(dao);
        machine.disableSpokeCaliber(SPOKE_CHAIN_ID);

        deal(address(baseToken), address(bridgeAdapter), inputAmount, true);
        vm.startPrank(address(bridgeAdapter));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));
        vm.stopPrank();

        skip(1);

        // 1 complete Hub -> Spoke transfer + 1 complete Spoke -> Hub transfer + 1 pending Spoke -> Hub transfer
        cBridgeOut = new bytes[](2);
        cBridgeOut[0] = abi.encode(spokeBaseTokenAddr, inputAmount);
        cBridgeOut[1] = abi.encode(spokeAccountingTokenAddr, inputAmount);
        report = _buildSpokeCaliberAccountingReportWithTransfers(
            SPOKE_CHAIN_ID, blockNum + 1, blockTime + 1, true, 0, cBridgeIn, cBridgeOut
        );
        creForwarder.forwardReport(address(machine), report, DEFAULT_CRE_WORKFLOW_ID);

        vm.expectRevert(Errors.PendingBridgeTransfer.selector);
        vm.prank(dao);
        machine.disableSpokeCaliber(SPOKE_CHAIN_ID);
    }

    function test_DisableSpokeCaliber() public {
        vm.startPrank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));

        vm.expectEmit(true, false, false, false, address(machine));
        emit IMachine.SpokeCaliberDisabled(SPOKE_CHAIN_ID);
        machine.disableSpokeCaliber(SPOKE_CHAIN_ID);

        assertFalse(machine.isSpokeCaliberEnabled(SPOKE_CHAIN_ID));

        machine.setSpokeCaliber(SPOKE_CHAIN_ID - 1, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));
        machine.enableSpokeCaliber(SPOKE_CHAIN_ID);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID + 1, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));

        vm.expectEmit(true, false, false, false, address(machine));
        emit IMachine.SpokeCaliberDisabled(SPOKE_CHAIN_ID);
        machine.disableSpokeCaliber(SPOKE_CHAIN_ID);

        assertEq(machine.getSpokeCalibersLength(), 3);
        assertTrue(machine.isSpokeCaliberEnabled(SPOKE_CHAIN_ID - 1));
        assertFalse(machine.isSpokeCaliberEnabled(SPOKE_CHAIN_ID));
        assertTrue(machine.isSpokeCaliberEnabled(SPOKE_CHAIN_ID + 1));
    }
}
