// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {ITokenRegistry} from "src/interfaces/ITokenRegistry.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract TransferToSpokeCaliber_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function setUp() public virtual override {
        Machine_Integration_Concrete_Test.setUp();

        vm.prank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.prank(securityCouncil);
        vm.expectRevert(IMachine.RecoveryMode.selector);
        machine.transferToSpokeCaliber(IBridgeAdapter.Bridge.ACROSS_V3, 0, address(0), 0, 0);
    }

    function test_RevertWhen_CallerNotMechanic() public {
        vm.expectRevert(IMachine.UnauthorizedOperator.selector);
        machine.transferToSpokeCaliber(IBridgeAdapter.Bridge.ACROSS_V3, 0, address(0), 0, 0);

        vm.prank(securityCouncil);
        vm.expectRevert(IMachine.UnauthorizedOperator.selector);
        machine.transferToSpokeCaliber(IBridgeAdapter.Bridge.ACROSS_V3, 0, address(0), 0, 0);
    }

    function test_RevertGiven_ForeignTokenNotRegistered_FromCaliber() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ITokenRegistry.ForeignTokenNotRegistered.selector, address(baseToken), SPOKE_CHAIN_ID
            )
        );
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(IBridgeAdapter.Bridge.ACROSS_V3, SPOKE_CHAIN_ID, address(baseToken), 0, 0);
    }

    function test_RevertWhen_InvalidChainId() public {
        vm.expectRevert(IMachine.InvalidChainId.selector);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(IBridgeAdapter.Bridge.ACROSS_V3, SPOKE_CHAIN_ID, address(accountingToken), 0, 0);
    }

    function test_RevertWhen_SpokeBridgeAdapterNotSet() public {
        vm.prank(dao);
        machine.setSpokeCaliber(
            SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new IBridgeAdapter.Bridge[](0), new address[](0)
        );

        vm.expectRevert(IMachine.SpokeBridgeAdapterNotSet.selector);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(IBridgeAdapter.Bridge.ACROSS_V3, SPOKE_CHAIN_ID, address(accountingToken), 0, 0);
    }

    function test_RevertWhen_BridgeAdapterDoesNotExist() public {
        vm.startPrank(dao);
        machine.setSpokeCaliber(
            SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new IBridgeAdapter.Bridge[](0), new address[](0)
        );
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr);
        vm.stopPrank();

        vm.expectRevert(IBridgeController.BridgeAdapterDoesNotExist.selector);
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(IBridgeAdapter.Bridge.ACROSS_V3, SPOKE_CHAIN_ID, address(accountingToken), 0, 0);
    }

    function test_TransferToSpokeCaliber_AccountingToken_FullBalance() public {
        vm.startPrank(dao);
        address adapterAddr = machine.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, "");
        machine.setSpokeCaliber(
            SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new IBridgeAdapter.Bridge[](0), new address[](0)
        );
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr);
        vm.stopPrank();

        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount, true);

        vm.expectEmit(true, true, false, false, adapterAddr);
        emit IBridgeAdapter.ScheduleOutBridgeTransfer(
            IBridgeAdapter(adapterAddr).nextOutTransferId(),
            _buildBridgeMessageHash(
                adapterAddr, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, spokeAccountingTokenAddr, 0
            )
        );

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(SPOKE_CHAIN_ID, address(accountingToken), inputAmount);

        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            IBridgeAdapter.Bridge.ACROSS_V3, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, 0
        );

        assertEq(accountingToken.balanceOf(address(machine)), 0);
        assertEq(accountingToken.balanceOf(adapterAddr), inputAmount);
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_TransferToSpokeCaliber_AccountingToken_PartialBalance() public {
        vm.startPrank(dao);
        address adapterAddr = machine.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, "");
        machine.setSpokeCaliber(
            SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new IBridgeAdapter.Bridge[](0), new address[](0)
        );
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr);
        vm.stopPrank();

        uint256 inputAmount = 2e18;
        deal(address(accountingToken), address(machine), inputAmount, true);

        uint256 transferAmount = inputAmount / 2;

        vm.expectEmit(true, true, false, false, adapterAddr);
        emit IBridgeAdapter.ScheduleOutBridgeTransfer(
            IBridgeAdapter(adapterAddr).nextOutTransferId(),
            _buildBridgeMessageHash(
                adapterAddr, SPOKE_CHAIN_ID, address(accountingToken), transferAmount, spokeAccountingTokenAddr, 0
            )
        );

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(SPOKE_CHAIN_ID, address(accountingToken), transferAmount);

        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            IBridgeAdapter.Bridge.ACROSS_V3, SPOKE_CHAIN_ID, address(accountingToken), transferAmount, 0
        );

        assertEq(accountingToken.balanceOf(address(machine)), inputAmount - transferAmount);
        assertEq(accountingToken.balanceOf(adapterAddr), transferAmount);
    }

    function test_TransferToSpokeCaliber_BaseToken_FullBalance() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 2e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        vm.startPrank(address(caliber));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, "");
        vm.stopPrank();

        vm.startPrank(dao);
        address adapterAddr = machine.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, "");
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        machine.setSpokeCaliber(
            SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new IBridgeAdapter.Bridge[](0), new address[](0)
        );
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr);
        vm.stopPrank();

        vm.expectEmit(true, true, false, false, adapterAddr);
        emit IBridgeAdapter.ScheduleOutBridgeTransfer(
            IBridgeAdapter(adapterAddr).nextOutTransferId(),
            _buildBridgeMessageHash(adapterAddr, SPOKE_CHAIN_ID, address(baseToken), inputAmount, spokeBaseTokenAddr, 0)
        );

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(SPOKE_CHAIN_ID, address(baseToken), inputAmount);

        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            IBridgeAdapter.Bridge.ACROSS_V3, SPOKE_CHAIN_ID, address(baseToken), inputAmount, 0
        );

        assertEq(baseToken.balanceOf(address(machine)), 0);
        assertEq(baseToken.balanceOf(adapterAddr), inputAmount);
        assertFalse(machine.isIdleToken(address(baseToken)));
    }

    function test_TransferToSpokeCaliber_BaseToken_PartialBalance() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 2e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        vm.startPrank(address(caliber));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, "");
        vm.stopPrank();

        vm.startPrank(dao);
        address adapterAddr = machine.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, "");
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        machine.setSpokeCaliber(
            SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new IBridgeAdapter.Bridge[](0), new address[](0)
        );
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr);
        vm.stopPrank();

        uint256 transferAmount = inputAmount / 2;

        vm.expectEmit(true, true, false, false, adapterAddr);
        emit IBridgeAdapter.ScheduleOutBridgeTransfer(
            IBridgeAdapter(adapterAddr).nextOutTransferId(),
            _buildBridgeMessageHash(
                adapterAddr, SPOKE_CHAIN_ID, address(baseToken), transferAmount, spokeBaseTokenAddr, 0
            )
        );

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(SPOKE_CHAIN_ID, address(baseToken), transferAmount);

        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            IBridgeAdapter.Bridge.ACROSS_V3, SPOKE_CHAIN_ID, address(baseToken), transferAmount, 0
        );

        assertEq(baseToken.balanceOf(address(machine)), inputAmount - transferAmount);
        assertEq(baseToken.balanceOf(adapterAddr), transferAmount);
        assertTrue(machine.isIdleToken(address(baseToken)));
    }

    function _buildBridgeMessageHash(
        address bridgeAdapter,
        uint256 spokeChainId,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 minOutputAmount
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                IBridgeAdapter.BridgeMessage(
                    IBridgeAdapter(bridgeAdapter).nextOutTransferId(),
                    bridgeAdapter,
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
