// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AcrossV3BridgeAdapter} from "src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {ITokenRegistry} from "src/interfaces/ITokenRegistry.sol";
import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract ManageTransfer_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    AcrossV3BridgeAdapter public bridgeAdapter;

    function setUp() public virtual override {
        CaliberMailbox_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);

        tokenRegistry.setToken(address(accountingToken), hubChainId, hubAccountingTokenAddr);

        bridgeAdapter = AcrossV3BridgeAdapter(caliberMailbox.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, ""));

        caliberMailbox.setHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, hubBridgeAdapterAddr);

        vm.stopPrank();
    }

    function test_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(ICaliberMailbox.UnauthorizedCaller.selector);
        caliberMailbox.manageTransfer(address(0), 0, "");
    }

    function test_ManageTransfer_RevertWhen_OutputTokenNonBaseToken_FromBridgeAdapter() public {
        vm.expectRevert(ICaliber.NotBaseToken.selector);
        vm.prank(address(bridgeAdapter));
        caliberMailbox.manageTransfer(address(baseToken), 0, "");
    }

    function test_ManageTransfer_FromBridgeAdapter() public {
        uint256 bridgeInputAmount = 1e18;
        uint256 bridgeOutputAmount = 999e15;

        deal(address(accountingToken), address(bridgeAdapter), bridgeOutputAmount, true);

        vm.startPrank(address(bridgeAdapter));

        accountingToken.approve(address(caliberMailbox), bridgeOutputAmount);

        caliberMailbox.manageTransfer(
            address(accountingToken), bridgeOutputAmount, abi.encode(hubChainId, bridgeInputAmount)
        );

        assertEq(accountingToken.balanceOf(address(caliber)), bridgeOutputAmount);
        assertEq(accountingToken.balanceOf(address(caliberMailbox)), 0);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), 0);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 1);
        assertEq(accountingData.bridgesOut.length, 0);
        assertEq(accountingData.netAum, bridgeOutputAmount);

        (address token, uint256 amount) = abi.decode(accountingData.bridgesIn[0], (address, uint256));
        assertEq(token, address(accountingToken));
        assertEq(amount, bridgeInputAmount);
    }

    function test_RevertGiven_ForeignTokenNotRegistered_FromCaliber() public {
        vm.expectRevert(
            abi.encodeWithSelector(ITokenRegistry.ForeignTokenNotRegistered.selector, address(baseToken), hubChainId)
        );
        vm.prank(address(caliber));
        caliberMailbox.manageTransfer(address(baseToken), 0, abi.encode(IBridgeAdapter.Bridge.ACROSS_V3, 0));
    }

    function test_RevertGiven_HubBridgeAdapterNotSet_FromCaliber() public {
        vm.expectRevert(ICaliberMailbox.HubBridgeAdapterNotSet.selector);
        vm.prank(address(caliber));
        caliberMailbox.manageTransfer(address(accountingToken), 0, abi.encode(IBridgeAdapter.Bridge.CIRCLE_CCTP, 0));
    }

    function test_RevertGiven_BridgeAdapterDoesNotExist_FromCaliber() public {
        vm.prank(dao);
        caliberMailbox.setHubBridgeAdapter(IBridgeAdapter.Bridge.CIRCLE_CCTP, hubBridgeAdapterAddr);

        vm.expectRevert(IBridgeController.BridgeAdapterDoesNotExist.selector);
        vm.prank(address(caliber));
        caliberMailbox.manageTransfer(address(accountingToken), 0, abi.encode(IBridgeAdapter.Bridge.CIRCLE_CCTP, 0));
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
            address(accountingToken),
            bridgeInputAmount,
            abi.encode(IBridgeAdapter.Bridge.ACROSS_V3, bridgeMinOutputAmount)
        );

        assertEq(accountingToken.balanceOf(address(caliber)), 0);
        assertEq(accountingToken.balanceOf(address(caliberMailbox)), 0);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), bridgeInputAmount);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 0);
        assertEq(accountingData.bridgesOut.length, 1);
        assertEq(accountingData.netAum, 0);

        (address token, uint256 amount) = abi.decode(accountingData.bridgesOut[0], (address, uint256));
        assertEq(token, address(accountingToken));
        assertEq(amount, bridgeInputAmount);
    }
}
