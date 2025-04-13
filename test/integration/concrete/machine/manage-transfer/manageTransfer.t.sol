// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract ManageTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        machine.setSpokeCaliber(
            SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new IBridgeAdapter.Bridge[](0), new address[](0)
        );
        bridgeAdapter = IBridgeAdapter(
            machine.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "")
        );
        vm.stopPrank();
    }

    function test_RevertWhen_CallerNotAuthorized() public {
        vm.expectRevert(IMachine.UnauthorizedSender.selector);
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
        // call passes and token is still registered as idle
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_RevertWhen_PositiveBalanceAndTokenNonPriceable_FromHubCaliber() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        uint256 inputAmount = 1;
        deal(address(baseToken2), address(caliber), inputAmount, true);
        vm.startPrank(address(caliber));
        baseToken2.approve(address(machine), inputAmount);
        vm.expectRevert(
            abi.encodeWithSelector(IOracleRegistry.PriceFeedRouteNotRegistered.selector, address(baseToken2))
        );
        machine.manageTransfer(address(baseToken2), inputAmount, "");
    }

    function test_ManageTransfer_BaseToken_FromHubCaliber() public {
        uint256 inputAmount = 1;
        deal(address(baseToken), address(caliber), inputAmount, true);
        vm.startPrank(address(caliber));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, "");
        assertTrue(machine.isIdleToken(address(baseToken)));
    }

    function test_RevertGiven_InvalidChainId_FromHubCaliber() public {
        vm.prank(address(bridgeAdapter));
        vm.expectRevert(IMachine.InvalidChainId.selector);
        machine.manageTransfer(address(0), 0, abi.encode(SPOKE_CHAIN_ID + 1, 0));
    }

    function test_ManageTransfer_EmptyBalance_FromBridgeAdapter() public {
        vm.prank(address(bridgeAdapter));
        machine.manageTransfer(address(baseToken), 0, abi.encode(SPOKE_CHAIN_ID, 0));
        assertFalse(machine.isIdleToken(address(baseToken)));
    }

    function test_ManageTransfer_EmptyBalanceAndNonPriceableToken_FromBridgeAdapter() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        vm.prank(address(bridgeAdapter));
        machine.manageTransfer(address(baseToken2), 0, abi.encode(SPOKE_CHAIN_ID, 0));
        assertFalse(machine.isIdleToken(address(baseToken2)));
    }

    function test_ManageTransfer_AccountingToken_FromBridgeAdapter() public {
        uint256 inputAmount = 1;
        deal(address(accountingToken), address(bridgeAdapter), inputAmount, true);
        vm.startPrank(address(bridgeAdapter));
        accountingToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(accountingToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount));
        // call passes and token is still registered as idle
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_RevertWhen_PositiveBalanceAndTokenNonPriceable_FromBridgeAdapter() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        uint256 inputAmount = 1;
        deal(address(baseToken2), address(bridgeAdapter), inputAmount, true);
        vm.startPrank(address(bridgeAdapter));
        baseToken2.approve(address(machine), inputAmount);
        vm.expectRevert(
            abi.encodeWithSelector(IOracleRegistry.PriceFeedRouteNotRegistered.selector, address(baseToken2))
        );
        machine.manageTransfer(address(baseToken2), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount));
    }

    function test_ManageTransfer_BaseToken_FromBridgeAdapter() public {
        uint256 inputAmount = 1;
        deal(address(baseToken), address(bridgeAdapter), inputAmount, true);
        vm.startPrank(address(bridgeAdapter));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, abi.encode(SPOKE_CHAIN_ID, inputAmount));
        assertTrue(machine.isIdleToken(address(baseToken)));
    }
}
