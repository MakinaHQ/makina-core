// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockMachineEndpoint} from "test/mocks/MockMachineEndpoint.sol";
import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeAdapter_Integration_Concrete_Test} from "../LayerZeroV2BridgeAdapter.t.sol";

contract CancelOutBridgeTransfer_LayerZeroV2BridgeAdapter_Integration_Concrete_Test is
    LayerZeroV2BridgeAdapter_Integration_Concrete_Test
{
    function test_RevertWhen_ReentrantCall() public {
        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(token1), inputAmount, address(token2), 0
        );

        token1.scheduleReenter(
            MockERC20.Type.Before, address(bridgeAdapter1), abi.encodeCall(bridgeAdapter1.cancelOutBridgeTransfer, (0))
        );

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        bridgeAdapter1.cancelOutBridgeTransfer(nextOutTransferId);
    }

    function test_RevertWhen_CallerNotController() public {
        vm.expectRevert(Errors.NotController.selector);
        bridgeAdapter1.cancelOutBridgeTransfer(0);
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        vm.startPrank(address(bridgeController1));

        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        bridgeAdapter1.cancelOutBridgeTransfer(0);

        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        // Schedule and send the transfer
        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(token1), inputAmount, address(token2), 0
        );
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint128(0), uint128(0), type(uint256).max));

        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        bridgeAdapter1.cancelOutBridgeTransfer(nextOutTransferId);
    }

    function test_CancelScheduledTransfer() public {
        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(token1), inputAmount, address(token2), 0
        );

        vm.expectEmit(false, false, false, true, address(bridgeController1));
        emit MockMachineEndpoint.ManageTransfer(address(token1), inputAmount, abi.encode(chainId2, inputAmount, true));

        vm.expectEmit(true, false, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.OutBridgeTransferCancelled(nextOutTransferId);

        bridgeAdapter1.cancelOutBridgeTransfer(nextOutTransferId);

        assertEq(IERC20(address(token1)).balanceOf(address(bridgeController1)), inputAmount);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeAdapter1)), 0);
    }
}
