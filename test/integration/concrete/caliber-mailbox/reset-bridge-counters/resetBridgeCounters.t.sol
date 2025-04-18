// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IAcrossV3MessageHandler} from "src/interfaces/IAcrossV3MessageHandler.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract ResetBridgeCounters_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    function setUp() public virtual override {
        CaliberMailbox_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliberMailbox.resetBridgeCounters(address(0));
    }

    function test_ResetBridgeCounters_CountersAlreadyNull() public {
        address token = makeAddr("token");
        vm.expectEmit(true, true, false, false, address(caliberMailbox));
        emit ICaliberMailbox.ResetBridgeCounters(token);
        vm.prank(dao);
        caliberMailbox.resetBridgeCounters(token);
    }

    function test_ResetBridgeOutCounter()
        public
        withForeignTokenRegistered(address(accountingToken), hubChainId, hubAccountingTokenAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, hubBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;

        // schedule and send outgoing bridge transfer to increase bridgeOut counter
        deal(address(accountingToken), address(caliber), inputAmount, true);
        address bridgeAdapterAddr = caliberMailbox.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
        uint256 transferId = IBridgeAdapter(bridgeAdapterAddr).nextOutTransferId();
        vm.startPrank(mechanic);
        caliber.transferToHubMachine(
            address(accountingToken), inputAmount, abi.encode(IBridgeAdapter.Bridge.ACROSS_V3, inputAmount)
        );
        caliberMailbox.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId, abi.encode(1 days));
        vm.stopPrank();

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();

        assertEq(accountingData.bridgesOut.length, 1);
        _checkBridgeCounterValue(accountingData.bridgesOut[0], address(accountingToken), inputAmount);

        // reset the bridge counters
        vm.prank(dao);
        caliberMailbox.resetBridgeCounters(address(accountingToken));

        accountingData = caliberMailbox.getSpokeCaliberAccountingData();

        assertEq(accountingData.bridgesOut.length, 0);
    }

    function test_ResetBridgeInCounter()
        public
        withForeignTokenRegistered(address(accountingToken), hubChainId, hubAccountingTokenAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, hubBridgeAdapterAddr)
    {
        // receive and claim a transfer to increase bridgeIn counter
        uint256 inputAmount = 1e18;
        uint256 outputAmount = 1e18;
        address bridgeAdapterAddr = caliberMailbox.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
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
        caliberMailbox.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, messageHash);

        // send funds with message from bridge
        deal(address(accountingToken), address(bridgeAdapterAddr), outputAmount, true);
        vm.prank(address(acrossV3SpokePool));
        IAcrossV3MessageHandler(bridgeAdapterAddr).handleV3AcrossMessage(
            address(accountingToken), outputAmount, address(0), encodedMessage
        );

        // claim transfer
        vm.prank(mechanic);
        caliberMailbox.claimInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 1);
        _checkBridgeCounterValue(accountingData.bridgesIn[0], address(accountingToken), inputAmount);

        // reset the bridge counters
        vm.prank(dao);
        caliberMailbox.resetBridgeCounters(address(accountingToken));

        accountingData = caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 0);
    }
}
