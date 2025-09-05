// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {GuardianSignature} from "@wormhole/sdk/libraries/VaaLib.sol";

import {DecimalsUtils} from "src/libraries/DecimalsUtils.sol";
import {IAcrossV3MessageHandler} from "src/interfaces/IAcrossV3MessageHandler.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
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

    function test_RevertWhen_ReentrantCall() public {
        accountingToken.scheduleReenter(
            MockERC20.Type.Before, address(machine), abi.encodeCall(IMachine.updateTotalAum, ())
        );

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        vm.prank(address(caliber));
        machine.manageTransfer(address(accountingToken), 0, "");
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(Errors.RecoveryMode.selector);
        machine.updateTotalAum();
    }

    function test_RevertGiven_HubCaliberStale() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount);
        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position in caliber
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        skip(DEFAULT_CALIBER_POS_STALE_THRESHOLD - 1);

        machine.updateTotalAum();

        skip(1);

        vm.expectRevert(abi.encodeWithSelector(Errors.PositionAccountingStale.selector, SUPPLY_POS_ID));
        machine.updateTotalAum();
    }

    function test_RevertGiven_SpokeCaliberStale()
        public
        withTokenAsBT(address(baseToken))
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        skip(DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD - 1);

        // aum update does not revert
        machine.updateTotalAum();

        skip(1);

        // data age exceeds staleness threshold
        vm.expectRevert(abi.encodeWithSelector(Errors.CaliberAccountingStale.selector, SPOKE_CHAIN_ID));
        machine.updateTotalAum();
    }

    function test_RevertGiven_CaliberTransferCancelledAfterBeingClaimed()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        vm.prank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);

        // receive and claim incoming bridge transfer
        uint256 inputAmount = 1e18;
        _receiveAndClaimBridgeTransfer(
            SPOKE_CHAIN_ID,
            ACROSS_V3_BRIDGE_ID,
            spokeAccountingTokenAddr,
            inputAmount,
            address(accountingToken),
            inputAmount
        );

        // simulate the caliber transfer being cancelled by error
        skip(1);
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
        queriedData.bridgesOut = new bytes[](1);
        queriedData.bridgesOut[0] = abi.encode(spokeAccountingTokenAddr, 0);
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
    }

    function test_RevertGiven_MachineTransferCancelledAfterBeingClaimed()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        vm.prank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);

        address bridgeAdapterAddr = machine.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);
        uint256 transferId = IBridgeAdapter(bridgeAdapterAddr).nextOutTransferId();

        // schedule and send outgoing bridge transfer
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount, true);
        _sendBridgeTransfer(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(accountingToken), inputAmount);

        // cancel the transfer
        deal(address(accountingToken), bridgeAdapterAddr, inputAmount, true);
        vm.prank(mechanic);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        // simulate the machine transfer being received and claimed by spoke caliber
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
    }

    function test_UpdateTotalAum_WithZeroAum() public {
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_UnnoticedToken() public {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(machine), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0);
        machine.updateTotalAum();
        // check that unnoticed token is not accounted for
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_IdleAccountingToken() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount);
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
        emit IMachine.TotalAumUpdated(inputAmount * PRICE_B_A);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount * PRICE_B_A);
    }

    function test_UpdateTotalAum_PositiveHubCaliberAum() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount);
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
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);
    }

    function test_UpdateTotalAum_NegativeHubCaliberValue() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // increase caliber debt
        borrowModule.setRateBps(10_000 * 2);
        caliber.accountForPosition(acctInstruction);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_PositiveHubCaliberAumAndIdleToken() public {
        uint256 inputAmount = 1e18;

        // fund machine with accountingToken
        deal(address(accountingToken), address(machine), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);

        // fund caliber with accountingToken
        deal(address(accountingToken), address(caliber), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(2 * inputAmount);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 2 * inputAmount);
    }

    function test_UpdateTotalAum_NegativeHubCaliberValueAndIdleToken() public withTokenAsBT(address(baseToken)) {
        // fund machine with accountingToken
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machineDepositor), inputAmount);

        vm.startPrank(address(machineDepositor));
        accountingToken.approve(address(machine), inputAmount);
        machine.deposit(inputAmount, address(this), 0);
        vm.stopPrank();

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);

        uint256 inputAmount2 = 1e18;
        deal(address(baseToken), address(borrowModule), inputAmount2, true);

        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount2);
        ICaliber.Instruction memory acctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // increase caliber debt
        borrowModule.setRateBps(10_000 * 2);
        caliber.accountForPosition(acctInstruction);

        // check that machine total aum remains the same
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount);
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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(queriedData.netAum);
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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_BridgeInProgressFromMachineToSpokeCaliber()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;

        deal(address(accountingToken), address(machine), inputAmount, true);
        _sendBridgeTransfer(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(accountingToken), inputAmount);

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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE);
    }

    function test_UpdateTotalAum_BridgeCompletedFromMachineToSpokeCaliber()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;
        uint256 bridgeFee = 1e16;
        uint256 outputAmount = inputAmount - bridgeFee;

        deal(address(accountingToken), address(machine), inputAmount, true);
        _sendBridgeTransfer(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(accountingToken), inputAmount);

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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), outputAmount + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE);
    }

    function test_UpdateTotalAum_BridgeInProgressFromSpokeCaliberToMachine()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE);
    }

    function test_UpdateTotalAum_BridgeCompletedFromSpokeCaliberToMachine()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;
        uint256 bridgeFee = 1e16;
        uint256 outputAmount = inputAmount - bridgeFee;

        _receiveAndClaimBridgeTransfer(
            SPOKE_CHAIN_ID,
            ACROSS_V3_BRIDGE_ID,
            spokeAccountingTokenAddr,
            inputAmount,
            address(accountingToken),
            outputAmount
        );

        skip(1);
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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), outputAmount + TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE);
    }

    function test_UpdateTotalAum_BridgeInProgressBothDirection_SameToken()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        uint256 machineToCaliberInputAmount = 1e18;
        uint256 caliberToMachineInputAmount = 2e18;

        deal(address(accountingToken), address(machine), machineToCaliberInputAmount, true);
        _sendBridgeTransfer(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(accountingToken), machineToCaliberInputAmount);

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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
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
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        uint256 machineToCaliberInputAmount = 1e18;
        uint256 caliberToMachineInputAmount = 2e18;

        deal(address(accountingToken), address(machine), machineToCaliberInputAmount, true);
        _sendBridgeTransfer(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(accountingToken), machineToCaliberInputAmount);

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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
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
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        uint256 machineToCaliberInputAmount = 1e18;
        uint256 bridgeFee1 = 1e16;
        uint256 machineToCaliberOutputAmount = machineToCaliberInputAmount - bridgeFee1;

        uint256 caliberToMachineInputAmount = 2e18;
        uint256 bridgeFee2 = 3e16;
        uint256 caliberToMachineOutputAmount = caliberToMachineInputAmount - bridgeFee2;

        deal(address(accountingToken), address(machine), machineToCaliberInputAmount, true);
        _sendBridgeTransfer(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(accountingToken), machineToCaliberInputAmount);

        _receiveAndClaimBridgeTransfer(
            SPOKE_CHAIN_ID,
            ACROSS_V3_BRIDGE_ID,
            spokeAccountingTokenAddr,
            caliberToMachineInputAmount,
            address(accountingToken),
            caliberToMachineOutputAmount
        );

        skip(1);
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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
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
        withBridgeAdapter(ACROSS_V3_BRIDGE_ID)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        uint256 machineToCaliberInputAmount = 1e18;
        uint256 bridgeFee1 = 1e16;
        uint256 machineToCaliberOutputAmount = machineToCaliberInputAmount - bridgeFee1;

        uint256 caliberToMachineInputAmount = 2e18;
        uint256 bridgeFee2 = 3e16;
        uint256 caliberToMachineOutputAmount = caliberToMachineInputAmount - bridgeFee2;

        deal(address(accountingToken), address(machine), machineToCaliberInputAmount, true);
        _sendBridgeTransfer(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(accountingToken), machineToCaliberInputAmount);

        _receiveAndClaimBridgeTransfer(
            SPOKE_CHAIN_ID,
            ACROSS_V3_BRIDGE_ID,
            spokeBaseTokenAddr,
            caliberToMachineInputAmount,
            address(baseToken),
            caliberToMachineOutputAmount
        );

        skip(1);
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
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
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

    function test_UpdateTotalAum_NoFeesWhenZeroSupply() public {
        // machine was initialized at t = 1
        // reach end of fee mint cooldown
        vm.warp(DEFAULT_MACHINE_FEE_MINT_COOLDOWN + 1);

        uint256 shareSupply0 = IERC20(machine.shareToken()).totalSupply();

        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply0);

        // mint assets to machine
        uint256 assets = 1e30;
        accountingToken.mint(address(machine), assets);

        // move forward way past the fee mint cooldown
        vm.warp(DEFAULT_MACHINE_FEE_MINT_COOLDOWN * 1000);

        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply0);
    }

    function test_UpdateTotalAum_NoFeeWhenOngoingCooldown() public {
        uint256 inputAmount = 1e18;
        _deposit(inputAmount);

        // machine was initialized at t = 1
        // stay within the fee mint cooldown
        vm.warp(DEFAULT_MACHINE_FEE_MINT_COOLDOWN);

        uint256 shareSupply0 = IERC20(machine.shareToken()).totalSupply();

        machine.updateTotalAum();

        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply0);
    }

    function test_UpdateTotalAum_NoFeeWhenFeeManagerRatesTooLow() public {
        feeManager.setFixedFeeRate(0);
        feeManager.setPerfFeeRate(0);

        uint256 inputAmount = 1e18;
        _deposit(inputAmount);

        // machine was initialized at t = 1
        // reach end of fee mint cooldown
        vm.warp(DEFAULT_MACHINE_FEE_MINT_COOLDOWN + 1);

        uint256 shareSupply0 = IERC20(machine.shareToken()).totalSupply();

        machine.updateTotalAum();

        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply0);
    }

    function test_UpdateTotalAum_FixedFeeOnly() public {
        uint256 inputAmount = 1e18;
        _deposit(inputAmount);

        uint256 shareSupply1 = IERC20(machine.shareToken()).totalSupply();

        // machine was initialized at t = 1
        // reach end of fee mint cooldown
        vm.warp(DEFAULT_MACHINE_FEE_MINT_COOLDOWN + 1);

        uint256 fixedFee1 = feeManager.calculateFixedFee(shareSupply1, DEFAULT_MACHINE_FEE_MINT_COOLDOWN);

        // fixed fee should be minted and performance fee should be 0
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.FeesMinted(fixedFee1);
        machine.updateTotalAum();
        uint256 shareSupply2 = IERC20(machine.shareToken()).totalSupply();
        assertEq(shareSupply2, shareSupply1 + fixedFee1);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(dao)), fixedFee1);

        // stay within the fee mint cooldown
        skip(DEFAULT_MACHINE_FEE_MINT_COOLDOWN - 1);

        // no fee should be minted
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2);

        // reach end of fee mint cooldown
        skip(1);

        uint256 fixedFee2 = feeManager.calculateFixedFee(shareSupply2, DEFAULT_MACHINE_FEE_MINT_COOLDOWN);

        // fixed fee should be minted and performance fee should be 0
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.FeesMinted(fixedFee2);
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2 + fixedFee2);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(dao)), fixedFee1 + fixedFee2);
    }

    function test_UpdateTotalAum_FixedAndPerfFees() public {
        uint256 inputAmount = 1e18;
        _deposit(inputAmount);

        uint256 shareSupply1 = IERC20(machine.shareToken()).totalSupply();
        uint256 sharePrice1 = DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + 1) / (shareSupply1 + 1);

        // mint yield to machine
        uint256 yieldAmount = 1e16;
        accountingToken.mint(address(machine), yieldAmount);

        // machine was initialized at t = 1
        // reach end of fee mint cooldown
        vm.warp(DEFAULT_MACHINE_FEE_MINT_COOLDOWN + 1);

        uint256 fixedFee1 = feeManager.calculateFixedFee(shareSupply1, DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        uint256 adjustedSharePrice =
            DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + yieldAmount + 1) / (shareSupply1 + fixedFee1 + 1);
        uint256 perfFee1 = feeManager.calculatePerformanceFee(
            shareSupply1, sharePrice1, adjustedSharePrice, DEFAULT_MACHINE_FEE_MINT_COOLDOWN
        );
        assertGt(perfFee1, 0);

        // fixed fee and performance fee should be minted
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.FeesMinted(fixedFee1 + perfFee1);
        machine.updateTotalAum();
        uint256 shareSupply2 = IERC20(machine.shareToken()).totalSupply();
        uint256 sharePrice2 = DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + yieldAmount + 1) / (shareSupply2 + 1);
        assertEq(shareSupply2, shareSupply1 + fixedFee1 + perfFee1);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(dao)), fixedFee1 + perfFee1);

        // mint yield to machine
        yieldAmount = 1e16;
        accountingToken.mint(address(machine), yieldAmount);

        // stay within the fee mint cooldown
        skip(DEFAULT_MACHINE_FEE_MINT_COOLDOWN - 1);

        // no fees should be minted
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2);

        // reach end of fee mint cooldown
        skip(1);

        uint256 fixedFee2 = feeManager.calculateFixedFee(shareSupply2, DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        adjustedSharePrice =
            DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + 2 * yieldAmount + 1) / (shareSupply2 + fixedFee2 + 1);
        uint256 perfFee2 = feeManager.calculatePerformanceFee(
            shareSupply2, sharePrice2, adjustedSharePrice, DEFAULT_MACHINE_FEE_MINT_COOLDOWN
        );
        assertGt(perfFee2, 0);

        // fixed fee and performance fee should be minted again
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.FeesMinted(fixedFee2 + perfFee2);
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2 + fixedFee2 + perfFee2);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(dao)), fixedFee1 + perfFee1 + fixedFee2 + perfFee2);
    }

    function test_UpdateTotalAum_FixedAndPerfFees_FixedFeeReducedByCap() public {
        uint256 inputAmount = 1e18;
        _deposit(inputAmount);

        uint256 shareSupply1 = IERC20(machine.shareToken()).totalSupply();
        uint256 sharePrice1 = DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + 1) / (shareSupply1 + 1);

        // mint yield to machine
        uint256 yieldAmount = 1e16;
        accountingToken.mint(address(machine), yieldAmount);

        // machine was initialized at t = 1
        // reach end of fee mint cooldown
        vm.warp(DEFAULT_MACHINE_FEE_MINT_COOLDOWN + 1);

        // set max fee accrual rate to low value
        uint256 newMaxFixedFeeAccrualRate = 1;
        vm.prank(dao);
        machine.setMaxFixedFeeAccrualRate(newMaxFixedFeeAccrualRate);

        uint256 cappedFixedFee1 = shareSupply1 * DEFAULT_MACHINE_FEE_MINT_COOLDOWN * newMaxFixedFeeAccrualRate / 1e18;
        uint256 adjustedSharePrice =
            DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + yieldAmount + 1) / (shareSupply1 + cappedFixedFee1 + 1);
        uint256 perfFee1 = feeManager.calculatePerformanceFee(
            shareSupply1, sharePrice1, adjustedSharePrice, DEFAULT_MACHINE_FEE_MINT_COOLDOWN
        );
        assertGt(perfFee1, 0);

        // fixed fee and performance fee should be minted
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.FeesMinted(cappedFixedFee1 + perfFee1);
        machine.updateTotalAum();
        uint256 shareSupply2 = IERC20(machine.shareToken()).totalSupply();
        uint256 sharePrice2 = DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + yieldAmount + 1) / (shareSupply2 + 1);
        assertEq(shareSupply2, shareSupply1 + cappedFixedFee1 + perfFee1);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(dao)), cappedFixedFee1 + perfFee1);

        // mint yield to machine
        yieldAmount = 1e16;
        accountingToken.mint(address(machine), yieldAmount);

        // stay within the fee mint cooldown
        skip(DEFAULT_MACHINE_FEE_MINT_COOLDOWN - 1);

        // no fees should be minted
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2);

        // reach end of fee mint cooldown
        skip(1);

        // set max fixed fee accrual rate back to high value
        vm.prank(dao);
        machine.setMaxFixedFeeAccrualRate(DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE);

        uint256 fixedFee2 = feeManager.calculateFixedFee(shareSupply2, DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        adjustedSharePrice =
            DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + 2 * yieldAmount + 1) / (shareSupply2 + fixedFee2 + 1);
        uint256 perfFee2 = feeManager.calculatePerformanceFee(
            shareSupply2, sharePrice2, adjustedSharePrice, DEFAULT_MACHINE_FEE_MINT_COOLDOWN
        );
        assertGt(perfFee2, 0);

        // fixed fee and performance fee should be minted again
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.FeesMinted(fixedFee2 + perfFee2);
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2 + fixedFee2 + perfFee2);
        assertEq(
            IERC20(machine.shareToken()).balanceOf(address(dao)), cappedFixedFee1 + perfFee1 + fixedFee2 + perfFee2
        );
    }

    function test_UpdateTotalAum_FixedAndPerfFees_PerfFeeReducedByCap() public {
        uint256 inputAmount = 1e18;
        _deposit(inputAmount);

        uint256 shareSupply1 = IERC20(machine.shareToken()).totalSupply();

        // mint yield to machine
        uint256 yieldAmount = 1e16;
        accountingToken.mint(address(machine), yieldAmount);

        // machine was initialized at t = 1
        // reach end of fee mint cooldown
        vm.warp(DEFAULT_MACHINE_FEE_MINT_COOLDOWN + 1);

        // set max perf fee accrual rate to low value
        uint256 newMaxPerfFeeAccrualRate = 1;
        vm.prank(dao);
        machine.setMaxPerfFeeAccrualRate(newMaxPerfFeeAccrualRate);

        uint256 fixedFee1 = feeManager.calculateFixedFee(shareSupply1, DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        assertGt(fixedFee1, 0);
        uint256 adjustedSharePrice =
            DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + yieldAmount + 1) / (shareSupply1 + fixedFee1 + 1);
        uint256 cappedPerfFee1 = shareSupply1 * DEFAULT_MACHINE_FEE_MINT_COOLDOWN * newMaxPerfFeeAccrualRate / 1e18;

        // fixed fee and performance fee should be minted
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.FeesMinted(fixedFee1 + cappedPerfFee1);
        machine.updateTotalAum();
        uint256 shareSupply2 = IERC20(machine.shareToken()).totalSupply();
        uint256 sharePrice2 = DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + yieldAmount + 1) / (shareSupply2 + 1);
        assertEq(shareSupply2, shareSupply1 + fixedFee1 + cappedPerfFee1);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(dao)), fixedFee1 + cappedPerfFee1);

        // mint yield to machine
        yieldAmount = 1e16;
        accountingToken.mint(address(machine), yieldAmount);

        // stay within the fee mint cooldown
        skip(DEFAULT_MACHINE_FEE_MINT_COOLDOWN - 1);

        // no fees should be minted
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2);

        // reach end of fee mint cooldown
        skip(1);

        // set max perf fee accrual rate back to high value
        vm.prank(dao);
        machine.setMaxPerfFeeAccrualRate(DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE);

        uint256 fixedFee2 = feeManager.calculateFixedFee(shareSupply2, DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        adjustedSharePrice =
            DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + 2 * yieldAmount + 1) / (shareSupply2 + fixedFee2 + 1);
        uint256 perfFee2 = feeManager.calculatePerformanceFee(
            shareSupply2, sharePrice2, adjustedSharePrice, DEFAULT_MACHINE_FEE_MINT_COOLDOWN
        );
        assertGt(perfFee2, 0);

        // fixed fee and performance fee should be minted again
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.FeesMinted(fixedFee2 + perfFee2);
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2 + fixedFee2 + perfFee2);
        assertEq(
            IERC20(machine.shareToken()).balanceOf(address(dao)), fixedFee1 + cappedPerfFee1 + fixedFee2 + perfFee2
        );
    }

    function test_UpdateTotalAum_FeeWithRemainingDust() public {
        uint256 inputAmount = 1e18;
        _deposit(inputAmount);

        uint256 shareSupply1 = IERC20(machine.shareToken()).totalSupply();

        // mint yield to machine
        uint256 yieldAmount = 1e16;
        accountingToken.mint(address(machine), yieldAmount);

        // machine was initialized at t = 1
        // reach end of fee mint cooldown
        vm.warp(DEFAULT_MACHINE_FEE_MINT_COOLDOWN + 1);

        uint256 fixedFee1 = feeManager.calculateFixedFee(shareSupply1, DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        uint256 perfFee1;
        {
            uint256 sharePrice1 = DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + 1) / (shareSupply1 + 1);
            uint256 newAdjustedSharePrice =
                DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + yieldAmount + 1) / (shareSupply1 + fixedFee1 + 1);
            perfFee1 = feeManager.calculatePerformanceFee(
                shareSupply1, sharePrice1, newAdjustedSharePrice, DEFAULT_MACHINE_FEE_MINT_COOLDOWN
            );
        }
        assertGt(perfFee1, 0);

        // set feeManager to distribute 60% of notified fees and ignore the rest
        feeManager.setDistributionRate(6e17);
        uint256 expectedMintedFees1 = (fixedFee1 + perfFee1) * 6e17 / 1e18;

        // fixed fee and performance fee should be minted
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.FeesMinted(expectedMintedFees1);
        machine.updateTotalAum();
        uint256 shareSupply2 = IERC20(machine.shareToken()).totalSupply();
        assertEq(shareSupply2, shareSupply1 + expectedMintedFees1);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(dao)), expectedMintedFees1);

        // mint yield to machine
        accountingToken.mint(address(machine), yieldAmount);

        // stay within the fee mint cooldown
        skip(DEFAULT_MACHINE_FEE_MINT_COOLDOWN - 1);

        // no fees should be minted
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2);

        // reach end of fee mint cooldown
        skip(1);

        uint256 fixedFee2 = feeManager.calculateFixedFee(shareSupply2, DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        uint256 perfFee2;
        {
            uint256 sharePrice2 = DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + yieldAmount + 1) / (shareSupply2 + 1);
            uint256 newAdjustedSharePrice =
                DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + 2 * yieldAmount + 1) / (shareSupply2 + fixedFee2 + 1);
            perfFee2 = feeManager.calculatePerformanceFee(
                shareSupply2, sharePrice2, newAdjustedSharePrice, DEFAULT_MACHINE_FEE_MINT_COOLDOWN
            );
        }
        assertGt(perfFee2, 0);

        // set feeManager to ignore 100% of notified fees
        feeManager.setDistributionRate(0);

        // fixed fee and performance fee should be minted again
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(dao)), expectedMintedFees1);

        // mint yield to machine
        accountingToken.mint(address(machine), yieldAmount);

        // stay within the fee mint cooldown
        skip(DEFAULT_MACHINE_FEE_MINT_COOLDOWN - 1);

        // no fees should be minted
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2);

        // reach end of fee mint cooldown
        skip(1);

        uint256 fixedFee3 = feeManager.calculateFixedFee(shareSupply2, DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        uint256 perfFee3;
        {
            uint256 sharePrice3 =
                DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + 2 * yieldAmount + 1) / (shareSupply2 + 1);
            uint256 newAdjustedSharePrice =
                DecimalsUtils.SHARE_TOKEN_UNIT * (inputAmount + 3 * yieldAmount + 1) / (shareSupply2 + fixedFee3 + 1);
            perfFee3 = feeManager.calculatePerformanceFee(
                shareSupply2, sharePrice3, newAdjustedSharePrice, DEFAULT_MACHINE_FEE_MINT_COOLDOWN
            );
        }
        assertGt(perfFee3, 0);

        // set feeManager to distribute 100% of notified fees
        feeManager.setDistributionRate(1e18);

        // fixed fee and performance fee should be minted again
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.FeesMinted(fixedFee3 + perfFee3);
        machine.updateTotalAum();
        assertEq(IERC20(machine.shareToken()).totalSupply(), shareSupply2 + fixedFee3 + perfFee3);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(dao)), expectedMintedFees1 + fixedFee3 + perfFee3);
    }

    function _sendBridgeTransfer(uint256 chainId, uint16 bridgeId, address token, uint256 amount) internal {
        uint256 nextOutTransferId = IBridgeAdapter(machine.getBridgeAdapter(bridgeId)).nextOutTransferId();
        vm.startPrank(mechanic);
        machine.transferToSpokeCaliber(bridgeId, chainId, token, amount, amount);
        machine.sendOutBridgeTransfer(bridgeId, nextOutTransferId, abi.encode(1 days));
        vm.stopPrank();
    }

    function _receiveAndClaimBridgeTransfer(
        uint256 chainId,
        uint16 bridgeId,
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
            (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
                perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
            );
            machine.updateSpokeCaliberAccountingData(response, signatures);
        }
        // send funds with message from bridge
        if (bridgeId == ACROSS_V3_BRIDGE_ID) {
            deal(address(outputToken), address(bridgeAdapterAddr), outputAmount, true);
            vm.prank(address(acrossV3SpokePool));
            IAcrossV3MessageHandler(bridgeAdapterAddr).handleV3AcrossMessage(
                outputToken, outputAmount, address(0), encodedMessage
            );
        } else {
            revert("Unsupported bridge");
        }

        vm.prank(mechanic);
        machine.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, nextInTransferId);
    }

    function _deposit(uint256 inputAmount) internal {
        deal(address(accountingToken), address(machineDepositor), inputAmount, true);
        vm.startPrank(address(machineDepositor));
        accountingToken.approve(address(machine), inputAmount);
        machine.deposit(inputAmount, address(this), 0);
        vm.stopPrank();
    }
}
