// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract TransferToSpokeCaliber_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    function setUp() public virtual override {
        Machine_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        bridgeAdapter =
            IBridgeAdapter(machine.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, ""));
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr);
        vm.stopPrank();
    }

    function test_RevertWhen_ReentrantCall() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount, true);

        accountingToken.scheduleReenter(
            MockERC20.Type.Before,
            address(machine),
            abi.encodeCall(IMachine.transferToSpokeCaliber, (ACROSS_V3_BRIDGE_ID, 0, address(0), 0, 0))
        );

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, inputAmount
        );
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.prank(securityCouncil);
        vm.expectRevert(Errors.RecoveryMode.selector);
        machine.transferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, 0, address(0), 0, 0);
    }

    function test_RevertWhen_CallerNotMechanic() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.transferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, 0, address(0), 0, 0);

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.transferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, 0, address(0), 0, 0);
    }

    function test_RevertGiven_ForeignTokenNotRegistered_FromCaliber() public {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ForeignTokenNotRegistered.selector, address(baseToken), SPOKE_CHAIN_ID)
        );
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(baseToken), 0, 0);
    }

    function test_RevertWhen_InvalidChainId() public {
        vm.prank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID + 1, spokeAccountingTokenAddr);

        vm.expectRevert(Errors.InvalidChainId.selector);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID + 1, address(accountingToken), 0, 0);
    }

    function test_RevertWhen_SpokeBridgeAdapterNotSet() public {
        vm.expectRevert(Errors.SpokeBridgeAdapterNotSet.selector);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(CIRCLE_CCTP_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), 0, 0);
    }

    function test_RevertWhen_BridgeAdapterDoesNotExist()
        public
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, CIRCLE_CCTP_BRIDGE_ID, spokeBridgeAdapterAddr)
    {
        vm.expectRevert(Errors.BridgeAdapterDoesNotExist.selector);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(CIRCLE_CCTP_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), 0, 0);
    }

    function test_RevertGiven_OutTransferDisabled() public {
        vm.prank(riskManagerTimelock);
        machine.setOutTransferEnabled(ACROSS_V3_BRIDGE_ID, false);

        vm.expectRevert(Errors.OutTransferDisabled.selector);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), 0, 0);
    }

    function test_RevertWhen_MaxValueLossExceeded() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = (inputAmount * (10000 - DEFAULT_MAX_BRIDGE_LOSS_BPS) / 10000) - 1;

        deal(address(accountingToken), address(machine), inputAmount, true);

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, minOutputAmount
        );
    }

    function test_RevertWhen_MinOutputAmountExceedsInputAmount() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = inputAmount + 1;

        deal(address(accountingToken), address(machine), inputAmount, true);

        vm.expectRevert(Errors.MinOutputAmountExceedsInputAmount.selector);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, minOutputAmount
        );
    }

    function test_TransferToSpokeCaliber_AccountingToken_FullBalance() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount, true);

        vm.expectEmit(true, true, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.ScheduleOutBridgeTransfer(
            bridgeAdapter.nextOutTransferId(),
            _buildBridgeMessageHash(
                address(bridgeAdapter),
                SPOKE_CHAIN_ID,
                address(accountingToken),
                inputAmount,
                spokeAccountingTokenAddr,
                inputAmount
            )
        );

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(SPOKE_CHAIN_ID, address(accountingToken), inputAmount);

        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, inputAmount
        );

        assertEq(accountingToken.balanceOf(address(machine)), 0);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), inputAmount);
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_TransferToSpokeCaliber_AccountingToken_PartialBalance() public {
        uint256 inputAmount = 2e18;
        deal(address(accountingToken), address(machine), inputAmount, true);

        uint256 transferAmount = inputAmount / 2;

        vm.expectEmit(true, true, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.ScheduleOutBridgeTransfer(
            bridgeAdapter.nextOutTransferId(),
            _buildBridgeMessageHash(
                address(bridgeAdapter),
                SPOKE_CHAIN_ID,
                address(accountingToken),
                transferAmount,
                spokeAccountingTokenAddr,
                transferAmount
            )
        );

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(SPOKE_CHAIN_ID, address(accountingToken), transferAmount);

        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), transferAmount, transferAmount
        );

        assertEq(accountingToken.balanceOf(address(machine)), inputAmount - transferAmount);
        assertEq(accountingToken.balanceOf(address(bridgeAdapter)), transferAmount);
    }

    function test_TransferToSpokeCaliber_BaseToken_FullBalance() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 2e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        vm.startPrank(address(caliber));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, "");
        vm.stopPrank();

        vm.prank(dao);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);

        vm.expectEmit(true, true, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.ScheduleOutBridgeTransfer(
            bridgeAdapter.nextOutTransferId(),
            _buildBridgeMessageHash(
                address(bridgeAdapter), SPOKE_CHAIN_ID, address(baseToken), inputAmount, spokeBaseTokenAddr, inputAmount
            )
        );

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(SPOKE_CHAIN_ID, address(baseToken), inputAmount);

        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(baseToken), inputAmount, inputAmount
        );

        assertEq(baseToken.balanceOf(address(machine)), 0);
        assertEq(baseToken.balanceOf(address(bridgeAdapter)), inputAmount);
        assertFalse(machine.isIdleToken(address(baseToken)));
    }

    function test_TransferToSpokeCaliber_BaseToken_PartialBalance() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 2e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        vm.startPrank(address(caliber));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, "");
        vm.stopPrank();

        vm.prank(dao);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);

        uint256 transferAmount = inputAmount / 2;

        vm.expectEmit(true, true, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.ScheduleOutBridgeTransfer(
            bridgeAdapter.nextOutTransferId(),
            _buildBridgeMessageHash(
                address(bridgeAdapter),
                SPOKE_CHAIN_ID,
                address(baseToken),
                transferAmount,
                spokeBaseTokenAddr,
                transferAmount
            )
        );

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(SPOKE_CHAIN_ID, address(baseToken), transferAmount);

        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(baseToken), transferAmount, transferAmount
        );

        assertEq(baseToken.balanceOf(address(machine)), inputAmount - transferAmount);
        assertEq(baseToken.balanceOf(address(bridgeAdapter)), transferAmount);
        assertTrue(machine.isIdleToken(address(baseToken)));
    }

    function _buildBridgeMessageHash(
        address bridgeAdapterAddr,
        uint256 spokeChainId,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 minOutputAmount
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                IBridgeAdapter.BridgeMessage(
                    IBridgeAdapter(bridgeAdapterAddr).nextOutTransferId(),
                    bridgeAdapterAddr,
                    spokeBridgeAdapterAddr,
                    block.chainid,
                    spokeChainId,
                    address(inputToken),
                    inputAmount,
                    outputToken,
                    minOutputAmount
                )
            )
        );
    }
}
