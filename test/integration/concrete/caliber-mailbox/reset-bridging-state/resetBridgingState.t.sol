// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IAcrossV3MessageHandler} from "src/interfaces/IAcrossV3MessageHandler.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {Errors} from "src/libraries/Errors.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract ResetBridgingState_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    function setUp() public virtual override {
        CaliberMailbox_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliberMailbox.resetBridgingState(address(0));
    }

    function test_RevertWhen_TokenNotBaseToken() public {
        vm.expectRevert(Errors.NotBaseToken.selector);
        vm.prank(dao);
        caliberMailbox.resetBridgingState(address(baseToken));
    }

    function test_ResetBridgingState_CountersAlreadyNull() public {
        vm.expectEmit(true, false, false, false, address(caliberMailbox));
        emit IBridgeController.BridgingStateReset(address(accountingToken));
        vm.prank(dao);
        caliberMailbox.resetBridgingState(address(accountingToken));
    }

    function test_ResetBridgingState_ResetBridgeOutCounter()
        public
        withForeignTokenRegistered(address(accountingToken), hubChainId, hubAccountingTokenAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withHubBridgeAdapter(ACROSS_V3_BRIDGE_ID, hubBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;

        // schedule and send outgoing bridge transfer to increase bridgeOut counter
        deal(address(accountingToken), address(caliber), inputAmount, true);
        address bridgeAdapterAddr = caliberMailbox.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);
        uint256 transferId = IBridgeAdapter(bridgeAdapterAddr).nextOutTransferId();
        vm.startPrank(mechanic);
        caliber.transferToHubMachine(
            address(accountingToken), inputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, inputAmount)
        );
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId, abi.encode(1 days));
        vm.stopPrank();

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();

        assertEq(accountingData.bridgesOut.length, 1);
        _checkBridgeCounterValue(accountingData.bridgesOut[0], address(accountingToken), inputAmount);

        // reset the bridge counters
        vm.prank(dao);
        caliberMailbox.resetBridgingState(address(accountingToken));

        accountingData = caliberMailbox.getSpokeCaliberAccountingData();

        assertEq(accountingData.bridgesOut.length, 0);
    }

    function test_ResetBridgingState_ResetBridgeInCounter()
        public
        withForeignTokenRegistered(address(accountingToken), hubChainId, hubAccountingTokenAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withHubBridgeAdapter(ACROSS_V3_BRIDGE_ID, hubBridgeAdapterAddr)
    {
        // simulate incoming bridge transfer
        uint256 inputAmount = 1e18;
        uint256 outputAmount = 1e18;
        address bridgeAdapterAddr = caliberMailbox.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);
        uint256 transferId = IBridgeAdapter(bridgeAdapterAddr).nextInTransferId();
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                0,
                hubBridgeAdapterAddr,
                bridgeAdapterAddr,
                hubChainId,
                block.chainid,
                hubAccountingTokenAddr,
                inputAmount,
                address(accountingToken),
                outputAmount
            )
        );
        bytes32 messageHash = keccak256(encodedMessage);
        vm.prank(mechanic);
        caliberMailbox.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, messageHash);
        deal(address(accountingToken), address(bridgeAdapterAddr), outputAmount, true);
        vm.prank(address(acrossV3SpokePool));
        IAcrossV3MessageHandler(bridgeAdapterAddr).handleV3AcrossMessage(
            address(accountingToken), outputAmount, address(0), encodedMessage
        );

        // claim transfer
        vm.prank(mechanic);
        caliberMailbox.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 1);
        _checkBridgeCounterValue(accountingData.bridgesIn[0], address(accountingToken), inputAmount);

        // reset the bridge counters
        vm.prank(dao);
        caliberMailbox.resetBridgingState(address(accountingToken));

        accountingData = caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 0);
    }

    function test_ResetBridgingState_WithdrawAdapterFunds()
        public
        withForeignTokenRegistered(address(accountingToken), hubChainId, hubAccountingTokenAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withHubBridgeAdapter(ACROSS_V3_BRIDGE_ID, hubBridgeAdapterAddr)
    {
        uint256 amount1 = 1e18;
        uint256 amount2 = 2e19;
        uint256 amount3 = 3e20;

        address bridgeAdapterAddr = caliberMailbox.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);

        // simulate incoming bridge transfer
        uint256 transferId = IBridgeAdapter(bridgeAdapterAddr).nextInTransferId();
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                0,
                hubBridgeAdapterAddr,
                bridgeAdapterAddr,
                hubChainId,
                block.chainid,
                hubAccountingTokenAddr,
                amount1,
                address(accountingToken),
                amount1
            )
        );
        bytes32 messageHash = keccak256(encodedMessage);
        vm.prank(mechanic);
        caliberMailbox.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, messageHash);
        deal(address(accountingToken), address(bridgeAdapterAddr), amount1, true);
        vm.prank(address(acrossV3SpokePool));
        IAcrossV3MessageHandler(bridgeAdapterAddr).handleV3AcrossMessage(
            address(accountingToken), amount1, address(0), encodedMessage
        );

        // schedule outgoing bridge transfer
        deal(address(accountingToken), address(caliber), amount2, true);
        transferId = IBridgeAdapter(bridgeAdapterAddr).nextOutTransferId();
        vm.prank(mechanic);
        caliber.transferToHubMachine(address(accountingToken), amount2, abi.encode(ACROSS_V3_BRIDGE_ID, amount2));

        // mint some extra tokens to the bridge adapter
        accountingToken.mint(bridgeAdapterAddr, amount3);

        vm.prank(dao);
        caliberMailbox.resetBridgingState(address(accountingToken));
        assertEq(accountingToken.balanceOf(address(caliber)), amount1 + amount2 + amount3);
        assertEq(accountingToken.balanceOf(bridgeAdapterAddr), 0);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();

        assertEq(accountingData.bridgesOut.length, 0);
        assertEq(accountingData.bridgesIn.length, 0);
    }
}
