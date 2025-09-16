// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {GuardianSignature} from "@wormhole/sdk/libraries/VaaLib.sol";

import {IAcrossV3MessageHandler} from "src/interfaces/IAcrossV3MessageHandler.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {PerChainData} from "test/utils/WormholeQueryTestHelpers.sol";
import {WormholeQueryTestHelpers} from "test/utils/WormholeQueryTestHelpers.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract ResetBridgingState_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function setUp() public virtual override {
        Machine_Integration_Concrete_Test.setUp();

        assertFalse(machine.isIdleToken(address(baseToken)));
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_RevertWhen_CallerNotSC() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.resetBridgingState(address(0));
    }

    function test_ResetBridgingState_EmptyBalance()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
    {
        vm.expectEmit(true, false, false, false, address(machine));
        emit IBridgeController.BridgingStateReset(address(accountingToken));
        vm.prank(securityCouncil);
        machine.resetBridgingState(address(accountingToken));
    }

    function test_ResetBridgingState_EmptyBalanceAndNonPriceableToken()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
    {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);

        vm.expectEmit(true, false, false, false, address(machine));
        emit IBridgeController.BridgingStateReset(address(baseToken2));
        vm.prank(securityCouncil);
        machine.resetBridgingState(address(baseToken2));
        assertFalse(machine.isIdleToken(address(baseToken2)));
    }

    function test_ResetBridgingState_PositiveBalance_AccountingToken()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
    {
        vm.expectEmit(true, false, false, false, address(machine));
        emit IBridgeController.BridgingStateReset(address(accountingToken));
        vm.prank(securityCouncil);
        machine.resetBridgingState(address(accountingToken));
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_RevertWhen_PositiveBalanceAndTokenNonPriceable_FromHubCaliber()
        public
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
    {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);

        address bridgeAdapterAddr = machine.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);
        deal(address(baseToken2), address(bridgeAdapterAddr), 1, true);

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(baseToken2)));
        vm.prank(securityCouncil);
        machine.resetBridgingState(address(baseToken2));
    }

    function test_ResetBridgingState_PositiveBalance_BaseToken()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
    {
        address bridgeAdapterAddr = machine.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);
        deal(address(baseToken), address(bridgeAdapterAddr), 1, true);

        vm.expectEmit(true, false, false, false, address(machine));
        emit IBridgeController.BridgingStateReset(address(baseToken));
        vm.prank(securityCouncil);
        machine.resetBridgingState(address(baseToken));
        assertTrue(machine.isIdleToken(address(baseToken)));
    }

    function test_ResetBridgingState_AccountingToken_WithdrawAdapterFunds()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withForeignTokenRegistered(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        uint256 amount1 = 1e18;
        uint256 amount2 = 2e19;
        uint256 amount3 = 3e20;

        address bridgeAdapterAddr = machine.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);

        // simulate incoming bridge transfer
        uint256 transferId = IBridgeAdapter(bridgeAdapterAddr).nextInTransferId();
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                0,
                spokeBridgeAdapterAddr,
                bridgeAdapterAddr,
                SPOKE_CHAIN_ID,
                block.chainid,
                spokeAccountingTokenAddr,
                amount1,
                address(accountingToken),
                amount1
            )
        );
        bytes32 messageHash = keccak256(encodedMessage);
        vm.prank(mechanic);
        machine.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, messageHash);
        deal(address(accountingToken), address(bridgeAdapterAddr), amount1, true);
        vm.prank(address(acrossV3SpokePool));
        IAcrossV3MessageHandler(bridgeAdapterAddr).handleV3AcrossMessage(
            address(accountingToken), amount1, address(0), encodedMessage
        );

        // schedule outgoing bridge transfer
        deal(address(accountingToken), address(machine), amount2, true);
        transferId = IBridgeAdapter(bridgeAdapterAddr).nextOutTransferId();
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), amount2, amount2);

        // mint some extra tokens to the bridge adapter
        accountingToken.mint(bridgeAdapterAddr, amount3);

        vm.prank(securityCouncil);
        machine.resetBridgingState(address(accountingToken));
        assertEq(accountingToken.balanceOf(address(machine)), amount1 + amount2 + amount3);
        assertEq(accountingToken.balanceOf(bridgeAdapterAddr), 0);
    }

    function test_ResetBridgingState_BaseToken_WithdrawAdapterFunds()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withForeignTokenRegistered(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        uint256 amount1 = 1e18;
        uint256 amount2 = 2e19;
        uint256 amount3 = 3e20;

        address bridgeAdapterAddr = machine.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);

        // simulate incoming bridge transfer
        uint256 transferId = IBridgeAdapter(bridgeAdapterAddr).nextInTransferId();
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                0,
                spokeBridgeAdapterAddr,
                bridgeAdapterAddr,
                SPOKE_CHAIN_ID,
                block.chainid,
                spokeBaseTokenAddr,
                amount1,
                address(baseToken),
                amount1
            )
        );
        bytes32 messageHash = keccak256(encodedMessage);
        vm.prank(mechanic);
        machine.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, messageHash);
        deal(address(baseToken), address(bridgeAdapterAddr), amount1, true);
        vm.prank(address(acrossV3SpokePool));
        IAcrossV3MessageHandler(bridgeAdapterAddr).handleV3AcrossMessage(
            address(baseToken), amount1, address(0), encodedMessage
        );

        // schedule outgoing bridge transfer
        deal(address(baseToken), address(machine), amount2, true);
        transferId = IBridgeAdapter(bridgeAdapterAddr).nextOutTransferId();
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(baseToken), amount2, amount2);

        // mint some extra tokens to the bridge adapter
        baseToken.mint(bridgeAdapterAddr, amount3);

        vm.prank(securityCouncil);
        machine.resetBridgingState(address(baseToken));
        assertEq(baseToken.balanceOf(address(machine)), amount1 + amount2 + amount3);
        assertEq(baseToken.balanceOf(bridgeAdapterAddr), 0);
        assertTrue(machine.isIdleToken(address(baseToken)));
    }

    function test_ResetBridgingState_UnlockAUMCalculation()
        public
        withForeignTokenRegistered(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr)
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;
        // schedule and send outgoing bridge transfer
        deal(address(accountingToken), address(machine), inputAmount, true);
        address bridgeAdapterAddr = machine.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);
        uint256 transferId = IBridgeAdapter(bridgeAdapterAddr).nextOutTransferId();
        vm.startPrank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, inputAmount
        );
        machine.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId, abi.encode(1 days));
        vm.stopPrank();

        // cancel the transfer
        deal(address(accountingToken), bridgeAdapterAddr, inputAmount, true);
        vm.prank(mechanic);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        // simulate the machine transfer being received and claimed by spoke caliber
        skip(1);
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
        queriedData.bridgesIn = new bytes[](1);
        queriedData.bridgesIn[0] = abi.encode(spokeAccountingTokenAddr, inputAmount);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // aum update now reverts
        vm.expectRevert(Errors.BridgeStateMismatch.selector);
        machine.updateTotalAum();

        // reset bridge-related state in machine
        vm.prank(securityCouncil);
        machine.resetBridgingState(address(accountingToken));

        // aum update now works
        machine.updateTotalAum();

        // simulate caliber notifying reset counters
        skip(1);
        blockTime = uint64(block.timestamp);
        queriedData.bridgesIn = new bytes[](0);
        perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (response, signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // aum update still works
        machine.updateTotalAum();
    }
}
