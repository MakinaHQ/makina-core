// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IMockAcrossV3SpokePool} from "test/mocks/IMockAcrossV3SpokePool.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {AcrossV3BridgeAdapter_Integration_Concrete_Test} from "../AcrossV3BridgeAdapter.t.sol";

contract SendOutBridgeTransfer_AcrossV3BridgeAdapter_Integration_Concrete_Test is
    AcrossV3BridgeAdapter_Integration_Concrete_Test
{
    uint256 public constant DEFAULT_FILL_DEADLINE_OFFSET = 1 hours;

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
            MockERC20.Type.Before,
            address(bridgeAdapter1),
            abi.encodeCall(bridgeAdapter1.sendOutBridgeTransfer, (0, ""))
        );

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(DEFAULT_FILL_DEADLINE_OFFSET));
    }

    function test_RevertWhen_CallerNotController() public {
        vm.expectRevert(IBridgeAdapter.NotController.selector);
        bridgeAdapter1.sendOutBridgeTransfer(0, "");
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        vm.expectRevert(IBridgeAdapter.InvalidTransferStatus.selector);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(DEFAULT_FILL_DEADLINE_OFFSET));
    }

    function test_SendOutBridgeTransfer() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        uint256 acrossV3DepositId = acrossV3SpokePool.numberOfDeposits();

        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                nextOutTransferId,
                address(bridgeAdapter1),
                address(bridgeAdapter2),
                block.chainid,
                chainId2,
                address(token1),
                inputAmount,
                address(token2),
                minOutputAmount
            )
        );

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(token1), inputAmount, address(token2), minOutputAmount
        );

        vm.expectEmit(true, false, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.SendOutBridgeTransfer(nextOutTransferId);

        vm.expectEmit(true, true, true, true, address(acrossV3SpokePool));
        emit IMockAcrossV3SpokePool.FundsDeposited(
            bytes32(uint256(uint160(address(token1)))),
            bytes32(uint256(uint160(address(token2)))),
            inputAmount,
            minOutputAmount,
            chainId2,
            acrossV3DepositId,
            uint32(block.timestamp),
            uint32(block.timestamp + DEFAULT_FILL_DEADLINE_OFFSET),
            0,
            bytes32(uint256(uint160(address(bridgeAdapter1)))),
            bytes32(uint256(uint160(address(bridgeAdapter2)))),
            bytes32(0),
            encodedMessage
        );

        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(DEFAULT_FILL_DEADLINE_OFFSET));

        assertEq(IERC20(address(token1)).balanceOf(address(bridgeController1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeAdapter1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(acrossV3SpokePool)), inputAmount);
    }
}
