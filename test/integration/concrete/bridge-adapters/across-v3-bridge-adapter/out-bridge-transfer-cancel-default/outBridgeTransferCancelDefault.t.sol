// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {AcrossV3BridgeAdapter_Integration_Concrete_Test} from "../AcrossV3BridgeAdapter.t.sol";

contract OutBridgeTransferCancelDefault_AcrossV3BridgeAdapter_Integration_Concrete_Test is
    AcrossV3BridgeAdapter_Integration_Concrete_Test
{
    function test_RevertGiven_InvalidTransferStatus() public {
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.outBridgeTransferCancelDefault(0);
    }

    function test_OutBridgeTransferCancelDefault_ScheduledTransfer() public {
        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(0, address(0), address(token1), inputAmount, address(0), 0);

        assertEq(bridgeAdapter1.outBridgeTransferCancelDefault(nextOutTransferId), 0);
    }

    function test_OutBridgeTransferCancelDefault_SentTransfer_WithoutFee() public {
        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();
        uint256 acrossV3DepositId = acrossV3SpokePool.numberOfDeposits();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(0, address(0), address(token1), inputAmount, address(0), 0);
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(1 hours));

        acrossV3SpokePool.cancelTransfer(acrossV3DepositId);

        assertEq(bridgeAdapter1.outBridgeTransferCancelDefault(nextOutTransferId), 0);
    }

    function test_OutBridgeTransferCancelDefault_SentTransfer_WithFee() public {
        // set a 1% cancellation fee
        uint256 cancelFeeBps = 100;
        acrossV3SpokePool.setCancelFeeBps(cancelFeeBps);

        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();
        uint256 acrossV3DepositId = acrossV3SpokePool.numberOfDeposits();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(0, address(0), address(token1), inputAmount, address(0), 0);
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(1 hours));

        acrossV3SpokePool.cancelTransfer(acrossV3DepositId);

        assertEq(bridgeAdapter1.outBridgeTransferCancelDefault(nextOutTransferId), cancelFeeBps * inputAmount / 10000);
    }
}
