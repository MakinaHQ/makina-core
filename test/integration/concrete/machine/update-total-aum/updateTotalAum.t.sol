// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";

import {AcrossV3BridgeAdapter} from "src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {PerChainData} from "test/utils/WormholeQueryTestHelpers.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";
import {WormholeQueryTestHelpers} from "test/utils/WormholeQueryTestHelpers.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract UpdateTotalAum_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        vm.stopPrank();
    }

    modifier withSpokeCaliber(uint256 chainId, address mailbox) {
        vm.prank(dao);
        machine.setSpokeCaliber(chainId, mailbox, new IBridgeAdapter.Bridge[](0), new address[](0));
        _;
    }

    modifier withBridgeAdapter(IBridgeAdapter.Bridge bridgeId) {
        vm.prank(dao);
        machine.createBridgeAdapter(bridgeId, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");
        _;
    }

    modifier withSpokeBridgeAdapter(uint256 chainId, IBridgeAdapter.Bridge bridgeId, address adapter) {
        vm.prank(dao);
        machine.setSpokeBridgeAdapter(chainId, bridgeId, adapter);
        _;
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(IMachine.RecoveryMode.selector);
        machine.updateTotalAum();
    }

    function test_RevertGiven_HubCaliberStale() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount);
        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, address(supplyModule)
        );

        // create position in caliber
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        skip(DEFAULT_CALIBER_POS_STALE_THRESHOLD - 1);

        machine.updateTotalAum();

        skip(1);

        vm.expectRevert(abi.encodeWithSelector(ICaliber.PositionAccountingStale.selector, SUPPLY_POS_ID));
        machine.updateTotalAum();
    }

    function test_RevertGiven_SpokeCaliberStale()
        public
        withTokenAsBT(address(baseToken))
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        vm.stopPrank();

        // update accounting data
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        skip(DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD - 1);

        // aum update does not revert
        machine.updateTotalAum();

        skip(1);

        // data age exceeds staleness threshold
        vm.expectRevert(abi.encodeWithSelector(IMachine.CaliberAccountingStale.selector, SPOKE_CHAIN_ID));
        machine.updateTotalAum();
    }

    function test_RevertGiven_CaliberTransferCancelledAfterBeingClaimed()
        public
        withTokenAsBT(address(baseToken))
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        vm.stopPrank();

        // receive and claim incoming bridge transfer
        uint256 inputAmount = 1e18;
        _receiveAndClaimBridgeTransfer(
            SPOKE_CHAIN_ID,
            IBridgeAdapter.Bridge.ACROSS_V3,
            spokeAccountingTokenAddr,
            inputAmount,
            address(accountingToken),
            inputAmount
        );

        // simulate the caliber transfer being cancelled by error
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
        queriedData.bridgesOut = new bytes[](1);
        queriedData.bridgesOut[0] = abi.encode(spokeAccountingTokenAddr, 0);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // aum update now reverts
        vm.expectRevert(IMachine.BridgeStateMismatch.selector);
        machine.updateTotalAum();
    }

    function test_RevertGiven_MachineTransferCancelledAfterBeingClaimed()
        public
        withTokenAsBT(address(baseToken))
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        vm.stopPrank();

        address bridgeAdapterAddr = machine.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
        uint256 transferId = IBridgeAdapter(bridgeAdapterAddr).nextOutTransferId();

        // schedule and send outgoing bridge transfer
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount, true);
        _sendBridgeTransfer(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, address(accountingToken), inputAmount);

        // cancel the transfer
        deal(address(accountingToken), bridgeAdapterAddr, inputAmount, true);
        vm.prank(mechanic);
        machine.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        // simulate the machine transfer being received and claimed by spoke caliber
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
        queriedData.bridgesIn = new bytes[](1);
        queriedData.bridgesIn[0] = abi.encode(spokeAccountingTokenAddr, inputAmount);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // aum update now reverts
        vm.expectRevert(IMachine.BridgeStateMismatch.selector);
        machine.updateTotalAum();
    }

    function test_UpdateTotalAum_WithZeroAum() public {
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_UnnoticedToken() public {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(machine), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0, block.timestamp);
        machine.updateTotalAum();
        // check that unnoticed token is not accounted for
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_IdleAccountingToken() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);
    }

    function test_UpdateTotalAum_IdleBaseToken() public {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount);

        vm.startPrank(address(caliber));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, "");
        vm.stopPrank();

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount * PRICE_B_A, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount * PRICE_B_A);
    }

    function test_UpdateTotalAum_PositiveHubCaliberAum() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);
    }

    function test_UpdateTotalAum_PositiveHubCaliberAumAndDebt() public withTokenAsBT(address(baseToken)) {
        // fund caliber with accountingToken
        uint256 inputAmount = 3e18;
        deal(address(accountingToken), address(caliber), inputAmount);

        uint256 inputAmount2 = 1e18;
        deal(address(baseToken), address(borrowModule), inputAmount2, true);

        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount2);
        ICaliber.Instruction memory acctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);
    }

    function test_UpdateTotalAum_NegativeHubCaliberValue() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // increase caliber debt
        borrowModule.setRateBps(10_000 * 2);
        caliber.accountForPosition(acctInstruction);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_PositiveHubCaliberAumAndIdleToken() public {
        uint256 inputAmount = 1e18;

        // fund machine with accountingToken
        deal(address(accountingToken), address(machine), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);

        // fund caliber with accountingToken
        deal(address(accountingToken), address(caliber), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(2 * inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 2 * inputAmount);
    }

    function test_UpdateTotalAum_NegativeHubCaliberValueAndIdleToken() public withTokenAsBT(address(baseToken)) {
        // fund machine with accountingToken
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machineDepositor), inputAmount);

        vm.startPrank(address(machineDepositor));
        accountingToken.approve(address(machine), inputAmount);
        machine.deposit(inputAmount, address(this));
        vm.stopPrank();

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);

        uint256 inputAmount2 = 1e18;
        deal(address(baseToken), address(borrowModule), inputAmount2, true);

        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount2);
        ICaliber.Instruction memory acctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // increase caliber debt
        borrowModule.setRateBps(10_000 * 2);
        caliber.accountForPosition(acctInstruction);

        // check that machine total aum remains the same
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);
    }

    function test_UpdateTotalAum_PositiveSpokeCaliberValue()
        public
        withTokenAsBT(address(baseToken))
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
    {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(queriedData.netAum, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), queriedData.netAum);
    }

    function test_UpdateTotalAum_NegativeSpokeCaliberValue()
        public
        withTokenAsBT(address(baseToken))
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
    {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(true);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_BridgeInProgressFromMachineToSpokeCaliber()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;

        deal(address(accountingToken), address(machine), inputAmount, true);
        _sendBridgeTransfer(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, address(accountingToken), inputAmount);

        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory bridgesIn;
        bytes[] memory bridgesOut;
        uint256 aumOffsetTransfers = 0;
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, aumOffsetTransfers, bridgesIn, bridgesOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE);
    }

    function test_UpdateTotalAum_BridgeCompletedFromMachineToSpokeCaliber()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;
        uint256 bridgeFee = 1e16;
        uint256 outputAmount = inputAmount - bridgeFee;

        deal(address(accountingToken), address(machine), inputAmount, true);
        _sendBridgeTransfer(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, address(accountingToken), inputAmount);

        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory bridgesIn = new bytes[](1);
        bridgesIn[0] = abi.encode(spokeAccountingTokenAddr, inputAmount);
        bytes[] memory bridgesOut;
        uint256 aumOffsetTransfers = outputAmount;
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, aumOffsetTransfers, bridgesIn, bridgesOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), outputAmount + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE);
    }

    function test_UpdateTotalAum_BridgeInProgressFromSpokeCaliberToMachine()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;

        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory bridgesIn;
        bytes[] memory bridgesOut = new bytes[](1);
        bridgesOut[0] = abi.encode(spokeAccountingTokenAddr, inputAmount);
        uint256 aumOffsetTransfers = 0;
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, aumOffsetTransfers, bridgesIn, bridgesOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE);
    }

    function test_UpdateTotalAum_BridgeCompletedFromSpokeCaliberToMachine()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;
        uint256 bridgeFee = 1e16;
        uint256 outputAmount = inputAmount - bridgeFee;

        _receiveAndClaimBridgeTransfer(
            SPOKE_CHAIN_ID,
            IBridgeAdapter.Bridge.ACROSS_V3,
            spokeAccountingTokenAddr,
            inputAmount,
            address(accountingToken),
            outputAmount
        );

        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory bridgesIn;
        bytes[] memory bridgesOut = new bytes[](1);
        bridgesOut[0] = abi.encode(spokeAccountingTokenAddr, inputAmount);
        uint256 aumOffsetTransfers = 0;
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, aumOffsetTransfers, bridgesIn, bridgesOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), outputAmount + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE);
    }

    function test_UpdateTotalAum_BridgeInProgressBothDirection_SameToken()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        uint256 machineToCaliberInputAmount = 1e18;
        uint256 caliberToMachineInputAmount = 2e18;

        deal(address(accountingToken), address(machine), machineToCaliberInputAmount, true);
        _sendBridgeTransfer(
            SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, address(accountingToken), machineToCaliberInputAmount
        );

        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory bridgesIn;
        bytes[] memory bridgesOut = new bytes[](1);
        bridgesOut[0] = abi.encode(spokeAccountingTokenAddr, caliberToMachineInputAmount);
        uint256 aumOffsetTransfers = 0;
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, aumOffsetTransfers, bridgesIn, bridgesOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(
            machine.lastTotalAum(),
            machineToCaliberInputAmount + caliberToMachineInputAmount + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE
        );
    }

    function test_UpdateTotalAum_BridgeInProgressBothDirection_DifferentToken()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        uint256 machineToCaliberInputAmount = 1e18;
        uint256 caliberToMachineInputAmount = 2e18;

        deal(address(accountingToken), address(machine), machineToCaliberInputAmount, true);
        _sendBridgeTransfer(
            SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, address(accountingToken), machineToCaliberInputAmount
        );

        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory bridgesIn;
        bytes[] memory bridgesOut = new bytes[](1);
        bridgesOut[0] = abi.encode(spokeBaseTokenAddr, caliberToMachineInputAmount);
        uint256 aumOffsetTransfers = 0;
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, aumOffsetTransfers, bridgesIn, bridgesOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(
            machine.lastTotalAum(),
            machineToCaliberInputAmount + (caliberToMachineInputAmount * PRICE_B_A)
                + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE
        );
    }

    function test_UpdateTotalAum_BridgeCompletedBothDirection_SameToken()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        uint256 machineToCaliberInputAmount = 1e18;
        uint256 bridgeFee1 = 1e16;
        uint256 machineToCaliberOutputAmount = machineToCaliberInputAmount - bridgeFee1;

        uint256 caliberToMachineInputAmount = 2e18;
        uint256 bridgeFee2 = 3e16;
        uint256 caliberToMachineOutputAmount = caliberToMachineInputAmount - bridgeFee2;

        deal(address(accountingToken), address(machine), machineToCaliberInputAmount, true);
        _sendBridgeTransfer(
            SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, address(accountingToken), machineToCaliberInputAmount
        );

        _receiveAndClaimBridgeTransfer(
            SPOKE_CHAIN_ID,
            IBridgeAdapter.Bridge.ACROSS_V3,
            spokeAccountingTokenAddr,
            caliberToMachineInputAmount,
            address(accountingToken),
            caliberToMachineOutputAmount
        );

        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory bridgesIn = new bytes[](1);
        bridgesIn[0] = abi.encode(spokeAccountingTokenAddr, machineToCaliberInputAmount);
        bytes[] memory bridgesOut = new bytes[](1);
        bridgesOut[0] = abi.encode(spokeAccountingTokenAddr, caliberToMachineInputAmount);
        uint256 aumOffsetTransfers = machineToCaliberOutputAmount;
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, aumOffsetTransfers, bridgesIn, bridgesOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(
            machine.lastTotalAum(),
            caliberToMachineOutputAmount + machineToCaliberOutputAmount + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE
        );
    }

    function test_UpdateTotalAum_BridgeCompletedBothDirection_DifferentToken()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        uint256 machineToCaliberInputAmount = 1e18;
        uint256 bridgeFee1 = 1e16;
        uint256 machineToCaliberOutputAmount = machineToCaliberInputAmount - bridgeFee1;

        uint256 caliberToMachineInputAmount = 2e18;
        uint256 bridgeFee2 = 3e16;
        uint256 caliberToMachineOutputAmount = caliberToMachineInputAmount - bridgeFee2;

        deal(address(accountingToken), address(machine), machineToCaliberInputAmount, true);
        _sendBridgeTransfer(
            SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, address(accountingToken), machineToCaliberInputAmount
        );

        _receiveAndClaimBridgeTransfer(
            SPOKE_CHAIN_ID,
            IBridgeAdapter.Bridge.ACROSS_V3,
            spokeBaseTokenAddr,
            caliberToMachineInputAmount,
            address(baseToken),
            caliberToMachineOutputAmount
        );

        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory bridgesIn = new bytes[](1);
        bridgesIn[0] = abi.encode(spokeAccountingTokenAddr, machineToCaliberInputAmount);
        bytes[] memory bridgesOut = new bytes[](1);
        bridgesOut[0] = abi.encode(spokeBaseTokenAddr, caliberToMachineInputAmount);
        uint256 aumOffsetTransfers = machineToCaliberOutputAmount;
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, aumOffsetTransfers, bridgesIn, bridgesOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(
            machine.lastTotalAum(),
            (caliberToMachineOutputAmount * PRICE_B_A) + machineToCaliberOutputAmount
                + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE
        );
    }

    function _sendBridgeTransfer(uint256 chainId, IBridgeAdapter.Bridge bridgeId, address token, uint256 amount)
        internal
    {
        uint256 nextOutTransferId = IBridgeAdapter(machine.getBridgeAdapter(bridgeId)).nextOutTransferId();
        vm.startPrank(mechanic);
        machine.transferToSpokeCaliber(bridgeId, chainId, address(token), amount, amount);
        machine.sendOutBridgeTransfer(bridgeId, nextOutTransferId, abi.encode(1 days));
        vm.stopPrank();
    }

    function _receiveAndClaimBridgeTransfer(
        uint256 chainId,
        IBridgeAdapter.Bridge bridgeId,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 outputAmount
    ) internal {
        address bridgeAdapterAddr = machine.getBridgeAdapter(bridgeId);
        uint256 nextInTransferId = IBridgeAdapter(bridgeAdapterAddr).nextInTransferId();

        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                0,
                spokeBridgeAdapterAddr,
                bridgeAdapterAddr,
                chainId,
                block.chainid,
                inputToken,
                inputAmount,
                outputToken,
                outputAmount
            )
        );
        bytes32 messageHash = keccak256(encodedMessage);

        vm.prank(mechanic);
        machine.authorizeInBridgeTransfer(bridgeId, messageHash);
        {
            // simulate the caliber having sent the transfer
            uint64 blockNum = 1e10;
            uint64 blockTime = uint64(block.timestamp);
            bytes[] memory cBridgeIn;
            bytes[] memory cBridgeOut = new bytes[](1);
            cBridgeOut[0] = abi.encode(inputToken, inputAmount);
            ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
                _buildSpokeCaliberAccountingDataWithTransfers(false, 0, cBridgeIn, cBridgeOut);
            PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
                WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
            );
            (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
                perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
            );
            machine.updateSpokeCaliberAccountingData(response, signatures);
        }
        // send funds with message from bridge
        if (bridgeId == IBridgeAdapter.Bridge.ACROSS_V3) {
            deal(address(outputToken), address(bridgeAdapterAddr), outputAmount, true);
            vm.prank(address(acrossV3SpokePool));
            AcrossV3BridgeAdapter(bridgeAdapterAddr).handleV3AcrossMessage(
                outputToken, outputAmount, address(0), encodedMessage
            );
        } else {
            revert("Unsupported bridge");
        }

        vm.prank(mechanic);
        machine.claimInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, nextInTransferId);
    }
}
