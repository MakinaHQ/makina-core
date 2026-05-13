// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICreReceiver} from "src/interfaces/ICreReceiver.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract OnReport_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));
    }

    function test_RevertWhen_ReentrantCall() public {
        accountingToken.scheduleReenter(
            MockERC20.Type.Before, address(machine), abi.encodeCall(ICreReceiver.onReport, ("", ""))
        );

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(machineDepositor);
        machine.deposit(0, address(0), 0, 0);
    }

    function test_RevertWhen_InvalidMetadata_FromForwarder() public {
        // invalid metadata length
        vm.expectRevert(Errors.InvalidCreMetadataLength.selector);
        vm.prank(address(creForwarder));
        machine.onReport("", "");

        // invalid workflow author
        address workflowAuthor = makeAddr("author");
        vm.prank(dao);
        machine.setCreWorkflowAuthor(workflowAuthor);
        vm.expectRevert(Errors.InvalidCreWorkflowAuthor.selector);
        creForwarder.forwardReport(address(machine), "", bytes32(0), address(0), bytes10(0));

        // invalid workflow name
        bytes10 workflowName = bytes10("name");
        vm.prank(dao);
        machine.addCreWorkflowName(workflowName);
        vm.expectRevert(Errors.InvalidCreWorkflowName.selector);
        creForwarder.forwardReport(address(machine), "", bytes32(0), workflowAuthor, bytes10(0));

        // invalid workflow id
        bytes32 workflowId = bytes32("id");
        vm.prank(dao);
        machine.addCreWorkflowId(workflowId);
        vm.expectRevert(Errors.InvalidCreWorkflowId.selector);
        creForwarder.forwardReport(address(machine), "", bytes32(0), address(0), bytes10(0));
    }

    function test_RevertWhen_UnauthorizedCaller() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.onReport("", "");
    }

    function test_RevertWhen_InvalidChainId() public {
        uint256 blockNum = 1e10;
        uint256 blockTime = block.timestamp;

        bytes memory report = _buildSpokeCaliberAccountingReport(SPOKE_CHAIN_ID + 1, blockNum, blockTime, false);

        vm.expectRevert(Errors.InvalidChainId.selector);
        creForwarder.forwardReport(address(machine), report, bytes32(0), DEFAULT_CRE_WORKFLOW_AUTHOR, bytes10(0));

        vm.expectRevert(Errors.InvalidChainId.selector);
        vm.prank(securityCouncil);
        machine.onReport("", report);
    }

    function test_RevertWhen_InvalidSpokeCaliberMailbox() public {
        uint256 blockNum = 1e10;
        uint256 blockTime = block.timestamp;

        spokeCaliberMailboxAddr = makeAddr("invalidMailbox");
        bytes memory report = _buildSpokeCaliberAccountingReport(SPOKE_CHAIN_ID, blockNum, blockTime, false);

        vm.expectRevert(Errors.InvalidSpokeCaliberMailbox.selector);
        creForwarder.forwardReport(address(machine), report, bytes32(0), DEFAULT_CRE_WORKFLOW_AUTHOR, bytes10(0));

        vm.expectRevert(Errors.InvalidSpokeCaliberMailbox.selector);
        vm.prank(securityCouncil);
        machine.onReport("", report);
    }

    function test_RevertWhen_StaleData() public {
        uint256 blockNum = 1e10;
        uint256 blockTime = block.timestamp;

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        vm.stopPrank();

        bytes memory report = _buildSpokeCaliberAccountingReport(
            SPOKE_CHAIN_ID, blockNum, blockTime - machine.caliberStaleThreshold(), false
        );

        vm.expectRevert(Errors.StaleData.selector);
        creForwarder.forwardReport(address(machine), report, bytes32(0), DEFAULT_CRE_WORKFLOW_AUTHOR, bytes10(0));

        // update data
        report = _buildSpokeCaliberAccountingReport(SPOKE_CHAIN_ID, blockNum, blockTime, false);
        creForwarder.forwardReport(address(machine), report, bytes32(0), DEFAULT_CRE_WORKFLOW_AUTHOR, bytes10(0));

        // data is older than previous data
        report = _buildSpokeCaliberAccountingReport(SPOKE_CHAIN_ID, blockNum, blockTime - 1, false);

        vm.expectRevert(Errors.StaleData.selector);
        creForwarder.forwardReport(address(machine), report, bytes32(0), DEFAULT_CRE_WORKFLOW_AUTHOR, bytes10(0));

        vm.expectRevert(Errors.StaleData.selector);
        vm.prank(securityCouncil);
        machine.onReport("", report);
    }

    function test_RevertWhen_TokenNotRegistered() public {
        uint256 blockNum = 1e10;
        uint256 blockTime = block.timestamp;

        bytes[] memory bridgesIn = new bytes[](1);
        bridgesIn[0] = abi.encode(spokeAccountingTokenAddr, 1e18);

        bytes memory report = _buildSpokeCaliberAccountingReportWithTransfers(
            SPOKE_CHAIN_ID, blockNum, blockTime, false, 1e18, bridgesIn, new bytes[](0)
        );

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LocalTokenNotRegistered.selector, spokeAccountingTokenAddr, SPOKE_CHAIN_ID)
        );
        creForwarder.forwardReport(address(machine), report, bytes32(0), DEFAULT_CRE_WORKFLOW_AUTHOR, bytes10(0));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LocalTokenNotRegistered.selector, spokeAccountingTokenAddr, SPOKE_CHAIN_ID)
        );
        vm.prank(securityCouncil);
        machine.onReport("", report);
    }

    function test_OnReport_FromCreForwarder() public {
        _test_OnReport(address(creForwarder));
    }

    function test_OnReport_FromSecurityCouncil() public {
        _test_OnReport(securityCouncil);
    }

    function _test_OnReport(address reporter) internal {
        uint256 blockNum = 1e10;
        uint256 blockTime = block.timestamp;

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        vm.stopPrank();

        bytes memory report = _buildSpokeCaliberAccountingReport(SPOKE_CHAIN_ID, blockNum, blockTime, false);
        if (reporter == address(creForwarder)) {
            creForwarder.forwardReport(address(machine), report, bytes32(0), DEFAULT_CRE_WORKFLOW_AUTHOR, bytes10(0));
        } else {
            vm.prank(reporter);
            machine.onReport("", report);
        }

        (uint256 netAum, uint256 timestamp) = machine.getSpokeCaliberNetAum(SPOKE_CHAIN_ID);
        assertEq(timestamp, blockTime);
        assertEq(netAum, SPOKE_CALIBER_NET_AUM);

        skip(1 days);

        (netAum, timestamp) = machine.getSpokeCaliberNetAum(SPOKE_CHAIN_ID);
        assertEq(timestamp, blockTime);
        assertEq(netAum, SPOKE_CALIBER_NET_AUM);
    }
}
