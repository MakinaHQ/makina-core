// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {Errors} from "src/libraries/Errors.sol";

import {BridgeAdapter_Integration_Concrete_Test} from "../BridgeAdapter.t.sol";

abstract contract WithdrawPendingFunds_Integration_Concrete_Test is BridgeAdapter_Integration_Concrete_Test {
    function setUp() public virtual override {}

    function test_RevertWhen_ReentrantCall() public {
        token1.scheduleReenter(
            MockERC20.Type.Before,
            address(bridgeAdapter1),
            abi.encodeCall(bridgeAdapter1.withdrawPendingFunds, (address(0)))
        );

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), 1000);

        // try reentrant call via claimInBridgeTransfer
        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        bridgeAdapter1.scheduleOutBridgeTransfer(0, address(0), address(token1), 1000, address(0), 0);
    }

    function test_RevertWhen_CallerNotController() public {
        vm.expectRevert(Errors.NotController.selector);
        bridgeAdapter1.withdrawPendingFunds(address(0));
    }

    function test_WithdrawendingFunds() public {
        uint256 amount1 = 1e18;
        uint256 amount2 = 2e19;
        uint256 amount3 = 3e20;
        uint256 amount4 = 4e21;

        deal(address(token1), address(bridgeController1), amount1 + amount2);

        vm.startPrank(address(bridgeController1));

        // schedule outgoing bridge transfer
        uint256 outTransferId1 = bridgeAdapter1.nextOutTransferId();
        token1.approve(address(bridgeAdapter1), amount1);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(token1), amount1, address(token2), amount1
        );

        // schedule and send outgoing bridge transfer
        uint256 outTransferId2 = bridgeAdapter1.nextOutTransferId();
        token1.approve(address(bridgeAdapter1), amount2);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(token1), amount2, address(token2), amount2
        );
        vm.stopPrank();
        _sendOutBridgeTransfer(address(bridgeAdapter1), outTransferId2);

        // simulate incoming bridge transfer reception
        uint256 inTransferId = bridgeAdapter1.nextInTransferId();
        _receiveInBridgeTransfer(
            address(bridgeAdapter1),
            abi.encode(
                IBridgeAdapter.BridgeMessage(
                    inTransferId,
                    address(bridgeAdapter2),
                    address(bridgeAdapter1),
                    chainId2,
                    block.chainid,
                    address(token2),
                    amount3,
                    address(token1),
                    amount3
                )
            ),
            address(token1),
            amount3
        );

        token1.mint(address(bridgeAdapter1), amount4);

        assertEq(IERC20(address(token1)).balanceOf(address(bridgeAdapter1)), amount1 + amount3 + amount4);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeController1)), 0);

        vm.expectEmit(true, true, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.WithdrawPendingFunds(address(token1), amount1 + amount3 + amount4);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.withdrawPendingFunds(address(token1));

        assertEq(IERC20(address(token1)).balanceOf(address(bridgeAdapter1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeController1)), amount1 + amount3 + amount4);

        // check that scheduled outgoing transfer cannot be sent
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.sendOutBridgeTransfer(outTransferId1, "");

        // check that scheduled outgoing transfer cannot be cancelled
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.cancelOutBridgeTransfer(outTransferId1);

        // check that sent outgoing transfer cannot be cancelled
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.cancelOutBridgeTransfer(outTransferId2);

        // check that received transfer can be claimed
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.claimInBridgeTransfer(inTransferId);
    }
}
