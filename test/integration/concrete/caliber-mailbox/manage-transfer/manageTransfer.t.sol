// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {AcrossV3BridgeAdapter} from "src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {Errors} from "src/libraries/Errors.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract ManageTransfer_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    AcrossV3BridgeAdapter public bridgeAdapter;

    function setUp() public virtual override {
        CaliberMailbox_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);

        tokenRegistry.setToken(address(accountingToken), hubChainId, hubAccountingTokenAddr);

        bridgeAdapter = AcrossV3BridgeAdapter(
            caliberMailbox.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "")
        );

        caliberMailbox.setHubBridgeAdapter(ACROSS_V3_BRIDGE_ID, hubBridgeAdapterAddr);

        vm.stopPrank();
    }

    function test_RevertWhen_ReentrantCall() public {
        uint256 bridgeInputAmount = 1e18;
        deal(address(accountingToken), address(caliber), bridgeInputAmount, true);

        accountingToken.scheduleReenter(
            MockERC20.Type.Before,
            address(caliberMailbox),
            abi.encodeCall(caliberMailbox.manageTransfer, (address(0), 0, ""))
        );

        vm.startPrank(address(caliber));

        accountingToken.approve(address(caliberMailbox), bridgeInputAmount);

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeInputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, bridgeInputAmount)
        );
    }

    function test_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.manageTransfer(address(0), 0, "");
    }

    function test_RevertGiven_ForeignTokenNotRegistered_FromCaliber() public {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ForeignTokenNotRegistered.selector, address(baseToken), hubChainId)
        );
        vm.prank(address(caliber));
        caliberMailbox.manageTransfer(address(baseToken), 0, "");
    }

    function test_RevertGiven_HubBridgeAdapterNotSet_FromCaliber() public {
        vm.expectRevert(Errors.HubBridgeAdapterNotSet.selector);
        vm.prank(address(caliber));
        caliberMailbox.manageTransfer(address(accountingToken), 0, abi.encode(CIRCLE_CCTP_BRIDGE_ID, 0));
    }

    function test_RevertGiven_BridgeAdapterDoesNotExist_FromCaliber()
        public
        withHubBridgeAdapter(CIRCLE_CCTP_BRIDGE_ID, hubBridgeAdapterAddr)
    {
        vm.expectRevert(Errors.BridgeAdapterDoesNotExist.selector);
        vm.prank(address(caliber));
        caliberMailbox.manageTransfer(address(accountingToken), 0, abi.encode(CIRCLE_CCTP_BRIDGE_ID, 0));
    }

    function test_RevertGiven_OutTransferDisabled_FromCaliber() public {
        vm.prank(riskManagerTimelock);
        caliberMailbox.setOutTransferEnabled(ACROSS_V3_BRIDGE_ID, false);

        vm.expectRevert(Errors.OutTransferDisabled.selector);
        vm.prank(address(caliber));
        caliberMailbox.manageTransfer(address(accountingToken), 0, abi.encode(ACROSS_V3_BRIDGE_ID, 0));
    }

    function test_RevertWhen_MaxValueLossExceeded_FromCaliber() public {
        uint256 bridgeInputAmount = 1e18;
        uint256 bridgeMinOutputAmount = (bridgeInputAmount * (10000 - DEFAULT_MAX_BRIDGE_LOSS_BPS) / 10000) - 1;

        deal(address(accountingToken), address(caliber), bridgeInputAmount, true);

        vm.startPrank(address(caliber));

        accountingToken.approve(address(caliberMailbox), bridgeInputAmount);

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeInputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, bridgeMinOutputAmount)
        );
    }

    function test_RevertWhen_MinOutputAmountExceedsInputAmount_FromCaliber() public {
        uint256 bridgeInputAmount = 1e18;
        uint256 bridgeMinOutputAmount = bridgeInputAmount + 1;

        deal(address(accountingToken), address(caliber), bridgeInputAmount, true);

        vm.startPrank(address(caliber));

        accountingToken.approve(address(caliberMailbox), bridgeInputAmount);

        vm.expectRevert(Errors.MinOutputAmountExceedsInputAmount.selector);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeInputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, bridgeMinOutputAmount)
        );
    }

    function test_ManageTransfer_FromCaliber() public {
        uint256 bridgeInputAmount = 1e18;
        uint256 bridgeMinOutputAmount = 999e15;

        deal(address(accountingToken), address(caliber), bridgeInputAmount, true);

        uint256 nextOutTransferId = bridgeAdapter.nextOutTransferId();
        bytes32 expectedMessageHash = keccak256(
            abi.encode(
                IBridgeAdapter.BridgeMessage(
                    nextOutTransferId,
                    address(bridgeAdapter),
                    hubBridgeAdapterAddr,
                    block.chainid,
                    hubChainId,
                    address(accountingToken),
                    bridgeInputAmount,
                    hubAccountingTokenAddr,
                    bridgeMinOutputAmount
                )
            )
        );

        vm.startPrank(address(caliber));

        accountingToken.approve(address(caliberMailbox), bridgeInputAmount);

        vm.expectEmit(true, true, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.ScheduleOutBridgeTransfer(nextOutTransferId, expectedMessageHash);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeInputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, bridgeMinOutputAmount)
        );

        assertEq(accountingToken.balanceOf(address(caliber)), 0);
        assertEq(accountingToken.balanceOf(address(caliberMailbox)), 0);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), bridgeInputAmount);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 0);
        assertEq(accountingData.bridgesOut.length, 1);
        assertEq(accountingData.netAum, 0);

        _checkBridgeCounterValue(accountingData.bridgesOut[0], address(accountingToken), bridgeInputAmount);
    }

    function test_ManageTransfer_Twice_FromCaliber() public {
        uint256 bridgeInputAmount = 1e18;

        deal(address(accountingToken), address(caliber), 2 * bridgeInputAmount, true);

        vm.startPrank(address(caliber));

        accountingToken.approve(address(caliberMailbox), bridgeInputAmount);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeInputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, bridgeInputAmount)
        );

        accountingToken.approve(address(caliberMailbox), bridgeInputAmount);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeInputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, bridgeInputAmount)
        );

        assertEq(accountingToken.balanceOf(address(caliber)), 0);
        assertEq(accountingToken.balanceOf(address(caliberMailbox)), 0);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), 2 * bridgeInputAmount);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 0);
        assertEq(accountingData.bridgesOut.length, 1);
        assertEq(accountingData.netAum, 0);

        _checkBridgeCounterValue(accountingData.bridgesOut[0], address(accountingToken), 2 * bridgeInputAmount);
    }

    function test_ManageTransfer_RevertWhen_OutputTokenNonBaseToken_FromBridgeAdapter() public {
        vm.expectRevert(Errors.NotBaseToken.selector);
        vm.prank(address(bridgeAdapter));
        caliberMailbox.manageTransfer(address(baseToken), 0, "");
    }

    function test_ManageTransfer_FromBridgeAdapter_NotRefund() public {
        uint256 bridgeInputAmount = 1e18;
        uint256 bridgeOutputAmount = 999e15;

        deal(address(accountingToken), address(bridgeAdapter), bridgeOutputAmount, true);

        vm.startPrank(address(bridgeAdapter));

        accountingToken.approve(address(caliberMailbox), bridgeOutputAmount);

        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeOutputAmount, abi.encode(hubChainId, bridgeInputAmount, false)
        );

        assertEq(accountingToken.balanceOf(address(caliber)), bridgeOutputAmount);
        assertEq(accountingToken.balanceOf(address(caliberMailbox)), 0);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), 0);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 1);
        assertEq(accountingData.bridgesOut.length, 0);
        assertEq(accountingData.netAum, bridgeOutputAmount);

        _checkBridgeCounterValue(accountingData.bridgesIn[0], address(accountingToken), bridgeInputAmount);
    }

    function test_ManageTransfer_Twice_FromBridgeAdapter_NotRefund() public {
        uint256 bridgeInputAmount = 1e18;
        uint256 bridgeOutputAmount = 999e15;

        deal(address(accountingToken), address(bridgeAdapter), 2 * bridgeOutputAmount, true);

        vm.startPrank(address(bridgeAdapter));

        accountingToken.approve(address(caliberMailbox), bridgeOutputAmount);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeOutputAmount, abi.encode(hubChainId, bridgeInputAmount, false)
        );

        accountingToken.approve(address(caliberMailbox), bridgeOutputAmount);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeOutputAmount, abi.encode(hubChainId, bridgeInputAmount, false)
        );

        assertEq(accountingToken.balanceOf(address(caliber)), 2 * bridgeOutputAmount);
        assertEq(accountingToken.balanceOf(address(caliberMailbox)), 0);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), 0);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 1);
        assertEq(accountingData.bridgesOut.length, 0);
        assertEq(accountingData.netAum, 2 * bridgeOutputAmount);

        (address token, uint256 amount) = abi.decode(accountingData.bridgesIn[0], (address, uint256));
        assertEq(token, address(accountingToken));
        assertEq(amount, 2 * bridgeInputAmount);
    }

    function test_ManageTransfer_BothDirection_NotRefund() public {
        uint256 amount1 = 1e18;
        uint256 amount2 = 999e15;

        deal(address(accountingToken), address(bridgeAdapter), amount2, true);

        vm.startPrank(address(bridgeAdapter));

        accountingToken.approve(address(caliberMailbox), amount2);
        caliberMailbox.manageTransfer(address(accountingToken), amount2, abi.encode(hubChainId, amount1, false));

        vm.startPrank(address(caliber));

        accountingToken.approve(address(caliberMailbox), amount2);
        caliberMailbox.manageTransfer(address(accountingToken), amount2, abi.encode(ACROSS_V3_BRIDGE_ID, amount2));

        assertEq(accountingToken.balanceOf(address(caliber)), 0);
        assertEq(accountingToken.balanceOf(address(caliberMailbox)), 0);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), amount2);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 1);
        assertEq(accountingData.bridgesOut.length, 1);
        assertEq(accountingData.netAum, 0);

        _checkBridgeCounterValue(accountingData.bridgesIn[0], address(accountingToken), amount1);
        _checkBridgeCounterValue(accountingData.bridgesOut[0], address(accountingToken), amount2);
    }

    function test_ManageTransfer_FromBridgeAdapter_Refund() public {
        uint256 bridgeInputAmount = 1e18;
        uint256 bridgeRefundAmount = 999e15;

        // transfer from caliber needed first before a refund can occur
        deal(address(accountingToken), address(caliber), bridgeInputAmount, true);
        vm.startPrank(address(caliber));
        accountingToken.approve(address(caliberMailbox), bridgeInputAmount);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeInputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, bridgeInputAmount)
        );
        vm.stopPrank();

        vm.startPrank(address(bridgeAdapter));
        accountingToken.approve(address(caliberMailbox), bridgeRefundAmount);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeRefundAmount, abi.encode(hubChainId, bridgeInputAmount, true)
        );

        assertEq(accountingToken.balanceOf(address(caliber)), bridgeRefundAmount);
        assertEq(accountingToken.balanceOf(address(caliberMailbox)), 0);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), bridgeInputAmount - bridgeRefundAmount);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 0);
        assertEq(accountingData.bridgesOut.length, 1);
        assertEq(accountingData.netAum, bridgeRefundAmount);

        _checkBridgeCounterValue(accountingData.bridgesOut[0], address(accountingToken), 0);
    }

    function test_ManageTransfer_Twice_FromBridgeAdapter_Refund() public {
        uint256 bridgeInputAmount = 1e18;
        uint256 bridgeRefundAmount = 999e15;

        // transfer from caliber needed first before a refund can occur
        deal(address(accountingToken), address(caliber), 2 * bridgeInputAmount, true);
        vm.startPrank(address(caliber));
        accountingToken.approve(address(caliberMailbox), 2 * bridgeInputAmount);
        caliberMailbox.manageTransfer(
            address(accountingToken), 2 * bridgeInputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, 2 * bridgeInputAmount)
        );
        vm.stopPrank();

        vm.startPrank(address(bridgeAdapter));

        accountingToken.approve(address(caliberMailbox), bridgeRefundAmount);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeRefundAmount, abi.encode(hubChainId, bridgeInputAmount, true)
        );

        accountingToken.approve(address(caliberMailbox), bridgeRefundAmount);
        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeRefundAmount, abi.encode(hubChainId, bridgeInputAmount, true)
        );

        assertEq(accountingToken.balanceOf(address(caliber)), 2 * bridgeRefundAmount);
        assertEq(accountingToken.balanceOf(address(caliberMailbox)), 0);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), 2 * bridgeInputAmount - 2 * bridgeRefundAmount);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 0);
        assertEq(accountingData.bridgesOut.length, 1);
        assertEq(accountingData.netAum, 2 * bridgeRefundAmount);

        _checkBridgeCounterValue(accountingData.bridgesOut[0], address(accountingToken), 0);
    }
}
