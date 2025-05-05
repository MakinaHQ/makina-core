// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {GuardianSignature} from "@wormhole/sdk/libraries/VaaLib.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMachineEndpoint} from "src/interfaces/IMachineEndpoint.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {PerChainData} from "test/utils/WormholeQueryTestHelpers.sol";
import {WormholeQueryTestHelpers} from "test/utils/WormholeQueryTestHelpers.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract ManageTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));
        bridgeAdapter =
            IBridgeAdapter(machine.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, ""));
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr);
        vm.stopPrank();

        assertFalse(machine.isIdleToken(address(baseToken)));
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_RevertWhen_ReentrantCall() public {
        accountingToken.scheduleReenter(
            MockERC20.Type.Before,
            address(machine),
            abi.encodeCall(IMachineEndpoint.manageTransfer, (address(0), 0, ""))
        );

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        vm.prank(address(caliber));
        machine.manageTransfer(address(accountingToken), 0, "");
    }

    function test_RevertWhen_CallerNotAuthorized() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.manageTransfer(address(0), 0, "");
    }

    function test_ManageTransfer_EmptyBalance_FromHubCaliber() public {
        vm.prank(address(caliber));
        machine.manageTransfer(address(baseToken), 0, "");
        assertFalse(machine.isIdleToken(address(baseToken)));
    }

    function test_ManageTransfer_EmptyBalanceAndNonPriceableToken_FromHubCaliber() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        vm.prank(address(caliber));
        machine.manageTransfer(address(baseToken2), 0, "");
        assertFalse(machine.isIdleToken(address(baseToken2)));
    }

    function test_ManageTransfer_AccountingToken_FromHubCaliber() public {
        uint256 inputAmount = 1;
        deal(address(accountingToken), address(caliber), inputAmount, true);
        vm.startPrank(address(caliber));
        accountingToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(accountingToken), inputAmount, "");

        assertEq(accountingToken.balanceOf(address(caliber)), 0);
        assertEq(accountingToken.balanceOf(address(machine)), inputAmount);
        // token is still registered as idle
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_RevertWhen_PositiveBalanceAndTokenNonPriceable_FromHubCaliber() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        uint256 inputAmount = 1;
        deal(address(baseToken2), address(caliber), inputAmount, true);
        vm.startPrank(address(caliber));
        baseToken2.approve(address(machine), inputAmount);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(baseToken2)));
        machine.manageTransfer(address(baseToken2), inputAmount, "");
    }

    function test_ManageTransfer_BaseToken_FromHubCaliber() public {
        uint256 inputAmount = 1;
        deal(address(baseToken), address(caliber), inputAmount, true);
        vm.startPrank(address(caliber));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, "");

        assertEq(baseToken.balanceOf(address(caliber)), 0);
        assertEq(baseToken.balanceOf(address(machine)), inputAmount);
        assertTrue(machine.isIdleToken(address(baseToken)));
    }

    function test_RevertGiven_InvalidChainId_FromBridgeAdapter() public {
        vm.prank(address(bridgeAdapter));
        vm.expectRevert(Errors.InvalidChainId.selector);
        machine.manageTransfer(address(0), 0, abi.encode(SPOKE_CHAIN_ID + 1, 0, false));
    }

    function test_RevertWhen_ReceivingUndeclaredTransfer() public {
        uint256 inputAmount = 1;

        // try to send undeclared transfer to machine
        vm.expectRevert(Errors.BridgeStateMismatch.selector);
        vm.prank(address(bridgeAdapter));
        machine.manageTransfer(address(accountingToken), 0, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));
    }

    function test_RevertWhen_PositiveBalanceAndTokenNonPriceable_FromBridgeAdapter_NotRefund() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        uint256 inputAmount = 1;
        vm.prank(dao);
        tokenRegistry.setToken(address(baseToken2), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        _simulateDeclaredTransferFromCaliber(spokeBaseTokenAddr, inputAmount);
        deal(address(baseToken2), address(bridgeAdapter), inputAmount, true);

        vm.startPrank(address(bridgeAdapter));
        baseToken2.approve(address(machine), inputAmount);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(baseToken2)));
        machine.manageTransfer(address(baseToken2), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));
    }

    function test_ManageTransfer_EmptyBalance_FromBridgeAdapter_NotRefund() public {
        uint256 inputAmount = 1;
        vm.prank(dao);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        _simulateDeclaredTransferFromCaliber(spokeBaseTokenAddr, inputAmount);

        vm.prank(address(bridgeAdapter));
        machine.manageTransfer(address(baseToken), 0, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));
        assertFalse(machine.isIdleToken(address(baseToken)));
    }

    function test_ManageTransfer_EmptyBalanceAndNonPriceableToken_FromBridgeAdapter_NotRefund() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        uint256 inputAmount = 1;
        vm.prank(dao);
        tokenRegistry.setToken(address(baseToken2), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        _simulateDeclaredTransferFromCaliber(spokeBaseTokenAddr, inputAmount);

        vm.prank(address(bridgeAdapter));
        machine.manageTransfer(address(baseToken2), 0, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));
        assertFalse(machine.isIdleToken(address(baseToken2)));
    }

    function test_ManageTransfer_AccountingToken_FromBridgeAdapter_NotRefund() public {
        uint256 inputAmount = 1;
        vm.prank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        _simulateDeclaredTransferFromCaliber(spokeAccountingTokenAddr, inputAmount);
        deal(address(accountingToken), address(bridgeAdapter), inputAmount, true);

        vm.startPrank(address(bridgeAdapter));
        accountingToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(accountingToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));

        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), 0);
        assertEq(accountingToken.balanceOf(address(machine)), inputAmount);
        // call passes and token is still registered as idle
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_ManageTransfer_Twice_AccountingToken_FromBridgeAdapter_NotRefund() public {
        uint256 inputAmount = 1;
        vm.prank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        _simulateDeclaredTransferFromCaliber(spokeAccountingTokenAddr, 2 * inputAmount);
        deal(address(accountingToken), address(bridgeAdapter), 2 * inputAmount, true);

        vm.startPrank(address(bridgeAdapter));

        accountingToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(accountingToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));

        accountingToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(accountingToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));

        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), 0);
        assertEq(accountingToken.balanceOf(address(machine)), 2 * inputAmount);
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_ManageTransfer_BaseToken_FromBridgeAdapter_NotRefund() public {
        uint256 inputAmount = 1;
        vm.prank(dao);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        _simulateDeclaredTransferFromCaliber(spokeBaseTokenAddr, inputAmount);
        deal(address(baseToken), address(bridgeAdapter), inputAmount, true);

        vm.startPrank(address(bridgeAdapter));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));

        assertEq(baseToken.balanceOf(address(bridgeAdapter)), 0);
        assertEq(baseToken.balanceOf(address(machine)), inputAmount);
        assertTrue(machine.isIdleToken(address(baseToken)));
    }

    function test_ManageTransfer_Twice_BaseToken_FromBridgeAdapter_NotRefund() public {
        uint256 inputAmount = 1;
        vm.prank(dao);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        _simulateDeclaredTransferFromCaliber(spokeBaseTokenAddr, 2 * inputAmount);
        deal(address(baseToken), address(bridgeAdapter), 2 * inputAmount, true);

        vm.startPrank(address(bridgeAdapter));

        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));

        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, false));

        assertEq(baseToken.balanceOf(address(bridgeAdapter)), 0);
        assertEq(baseToken.balanceOf(address(machine)), 2 * inputAmount);
        assertTrue(machine.isIdleToken(address(baseToken)));
    }

    function test_RevertWhen_RefundingCompletedTransfer() public {
        uint256 inputAmount = 1;

        vm.prank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);

        uint256 transferId = bridgeAdapter.nextOutTransferId();

        deal(address(accountingToken), address(machine), inputAmount, true);
        vm.startPrank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, inputAmount
        );
        machine.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId, abi.encode(1 days));
        vm.stopPrank();

        // simulate caliber having received the transfer
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory cBridgeIn = new bytes[](1);
        cBridgeIn[0] = abi.encode(spokeAccountingTokenAddr, inputAmount);
        bytes[] memory cBridgeOut;
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, 0, cBridgeIn, cBridgeOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // try to refund the transfer to machine
        vm.startPrank(address(bridgeAdapter));
        accountingToken.approve(address(machine), inputAmount);
        vm.expectRevert(Errors.BridgeStateMismatch.selector);
        machine.manageTransfer(address(accountingToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, true));
    }

    function test_RevertWhen_PositiveBalanceAndTokenNonPriceable_FromBridgeAdapter_Refund() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        uint256 inputAmount = 1;
        _simulateTransferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, address(baseToken2), inputAmount);

        vm.startPrank(address(bridgeAdapter));
        baseToken2.approve(address(machine), inputAmount);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(baseToken2)));
        machine.manageTransfer(address(baseToken2), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, true));
    }

    function test_ManageTransfer_EmptyBalance_FromBridgeAdapter_Refund() public {
        _simulateTransferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, address(baseToken), 0);

        vm.prank(address(bridgeAdapter));
        machine.manageTransfer(address(baseToken), 0, abi.encode(SPOKE_CHAIN_ID, 0, true));
        assertFalse(machine.isIdleToken(address(baseToken)));
    }

    function test_ManageTransfer_EmptyBalanceAndNonPriceableToken_FromBridgeAdapter_Refund() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        _simulateTransferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, address(baseToken2), 0);

        vm.prank(address(bridgeAdapter));
        machine.manageTransfer(address(baseToken2), 0, abi.encode(SPOKE_CHAIN_ID, 0, true));
        assertFalse(machine.isIdleToken(address(baseToken2)));
    }

    function test_ManageTransfer_AccountingToken_FromBridgeAdapter_Refund() public {
        uint256 inputAmount = 1;
        _simulateTransferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, address(accountingToken), inputAmount);

        vm.startPrank(address(bridgeAdapter));
        accountingToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(accountingToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, true));

        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), 0);
        assertEq(accountingToken.balanceOf(address(machine)), inputAmount);
        // call passes and token is still registered as idle
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_ManageTransfer_BaseToken_FromBridgeAdapter_Refund() public {
        uint256 inputAmount = 1;

        _simulateTransferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, address(baseToken), inputAmount);

        vm.startPrank(address(bridgeAdapter));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount, true));

        assertEq(baseToken.balanceOf(address(bridgeAdapter)), 0);
        assertEq(baseToken.balanceOf(address(machine)), inputAmount);
        assertTrue(machine.isIdleToken(address(baseToken)));
    }

    function _simulateTransferToSpokeCaliber(uint16 bridgeId, address token, uint256 inputAmount) internal {
        vm.prank(dao);
        tokenRegistry.setToken(token, SPOKE_CHAIN_ID, makeAddr("spokeToken"));

        deal(token, address(machine), inputAmount, true);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(bridgeId, SPOKE_CHAIN_ID, token, inputAmount, inputAmount);
    }

    function _simulateDeclaredTransferFromCaliber(address spokeToken, uint256 inputAmount) internal {
        // simulate caliber having sent the transfer
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory cBridgeIn;
        bytes[] memory cBridgeOut = new bytes[](1);
        cBridgeOut[0] = abi.encode(spokeToken, inputAmount);
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
}
