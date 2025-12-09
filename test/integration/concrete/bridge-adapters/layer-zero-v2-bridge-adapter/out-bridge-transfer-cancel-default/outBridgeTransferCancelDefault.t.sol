// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeAdapter_Integration_Concrete_Test} from "../LayerZeroV2BridgeAdapter.t.sol";

contract OutBridgeTransferCancelDefault_LayerZeroV2BridgeAdapter_Integration_Concrete_Test is
    LayerZeroV2BridgeAdapter_Integration_Concrete_Test
{
    function test_RevertGiven_InvalidTransferStatus() public {
        vm.startPrank(address(bridgeController1));

        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        bridgeAdapter1.outBridgeTransferCancelDefault(0);

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
        bridgeAdapter1.outBridgeTransferCancelDefault(nextOutTransferId);
    }

    function test_OutBridgeTransferCancelDefault_ScheduledTransfer() public {
        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(chainId2, address(0), address(token1), inputAmount, address(token2), 0);

        assertEq(bridgeAdapter1.outBridgeTransferCancelDefault(nextOutTransferId), 0);
    }
}
