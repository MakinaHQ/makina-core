// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {BridgeAdapter_Integration_Concrete_Test} from "../BridgeAdapter.t.sol";

abstract contract ScheduleOutBridgeTransfer_Integration_Concrete_Test is BridgeAdapter_Integration_Concrete_Test {
    function setUp() public virtual override {}

    function test_RevertWhen_ReentrantCall() public {
        token1.scheduleReenter(
            MockERC20.Type.Before,
            address(bridgeAdapter1),
            abi.encodeCall(bridgeAdapter1.scheduleOutBridgeTransfer, (0, address(0), address(0), 0, address(0), 0))
        );

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), 1000);

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        bridgeAdapter1.scheduleOutBridgeTransfer(0, address(0), address(token1), 1000, address(0), 0);
    }

    function test_RevertWhen_CallerNotController() public {
        vm.expectRevert(Errors.NotController.selector);
        bridgeAdapter1.scheduleOutBridgeTransfer(0, address(0), address(0), 0, address(0), 0);
    }

    function test_RevertGiven_InsufficientAllowance() public {
        uint256 inputAmount = 1e18;

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(bridgeAdapter1), 0, inputAmount
            )
        );
        vm.prank(address(bridgeController1));
        bridgeAdapter1.scheduleOutBridgeTransfer(0, address(0), address(token1), inputAmount, address(0), 0);
    }

    function test_RevertGiven_InsufficientBalance() public {
        uint256 inputAmount = 1e18;
        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(bridgeController1), 0, inputAmount
            )
        );
        bridgeAdapter1.scheduleOutBridgeTransfer(0, address(0), address(token1), inputAmount, address(0), 0);
    }

    function test_ScheduleOutBridgeTransfer() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        IBridgeAdapter.BridgeMessage memory message = IBridgeAdapter.BridgeMessage(
            nextOutTransferId,
            address(bridgeAdapter1),
            address(bridgeAdapter2),
            block.chainid,
            chainId2,
            address(token1),
            inputAmount,
            address(token2),
            minOutputAmount
        );
        bytes32 expectedMessageHash = keccak256(abi.encode(message));

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);

        vm.expectEmit(true, true, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.OutBridgeTransferScheduled(nextOutTransferId, expectedMessageHash);

        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(token1), inputAmount, address(token2), minOutputAmount
        );

        assertEq(bridgeAdapter1.nextOutTransferId(), nextOutTransferId + 1);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeController1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeAdapter1)), inputAmount);
    }
}
