// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract EnableSpokeCaliber_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter internal bridgeAdapter;

    function setUp() public virtual override {
        Machine_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        bridgeAdapter = IBridgeAdapter(
            hubCoreFactory.createBridgeAdapter(
                address(machine),
                IBridgeAdapterFactory.BridgeAdapterInitParams(ACROSS_V3_BRIDGE_ID, "", DEFAULT_MAX_BRIDGE_LOSS_BPS)
            )
        );
        vm.stopPrank();
    }

    function test_RevertWhen_ReentrantCall() public {
        accountingToken.scheduleReenter(
            MockERC20.Type.Before, address(machine), abi.encodeCall(IMachine.enableSpokeCaliber, (0))
        );

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(address(caliber));
        machine.manageTransfer(address(accountingToken), 0, "");
    }

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.enableSpokeCaliber(0);
    }

    function test_RevertWhen_InvalidChainId() public {
        vm.expectRevert(Errors.InvalidChainId.selector);
        vm.prank(dao);
        machine.enableSpokeCaliber(SPOKE_CHAIN_ID);
    }

    function test_RevertWhen_CaliberAlreadyEnabled() public {
        vm.startPrank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, address(spokeCaliberMailboxAddr), new uint16[](0), new address[](0));

        vm.expectRevert(Errors.AlreadyEnabled.selector);
        machine.enableSpokeCaliber(SPOKE_CHAIN_ID);
    }

    function test_EnableSpokeCaliber() public {
        vm.startPrank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));
        machine.disableSpokeCaliber(SPOKE_CHAIN_ID);

        vm.expectEmit(true, false, false, false, address(machine));
        emit IMachine.SpokeCaliberEnabled(SPOKE_CHAIN_ID);
        machine.enableSpokeCaliber(SPOKE_CHAIN_ID);

        assertEq(machine.getSpokeCalibersLength(), 1);
        assertTrue(machine.isSpokeCaliberEnabled(SPOKE_CHAIN_ID));
    }
}
