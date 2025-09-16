// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockMachineEndpoint} from "test/mocks/MockMachineEndpoint.sol";
import {Errors} from "src/libraries/Errors.sol";

import {BridgeAdapter_Integration_Concrete_Test} from "../BridgeAdapter.t.sol";

abstract contract ClaimInBridgeTransfer_Integration_Concrete_Test is BridgeAdapter_Integration_Concrete_Test {
    function setUp() public virtual override {}

    function test_RevertWhen_ReentrantCall() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;

        uint256 nextInTransferId = bridgeAdapter1.nextInTransferId();

        _receiveInBridgeTransfer(
            address(bridgeAdapter1),
            abi.encode(
                IBridgeAdapter.BridgeMessage(
                    nextInTransferId,
                    address(bridgeAdapter2),
                    address(bridgeAdapter1),
                    chainId2,
                    block.chainid,
                    address(token2),
                    inputAmount,
                    address(token1),
                    minOutputAmount
                )
            ),
            address(token1),
            minOutputAmount
        );

        token1.scheduleReenter(
            MockERC20.Type.Before, address(bridgeAdapter1), abi.encodeCall(bridgeAdapter1.claimInBridgeTransfer, (0))
        );

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.claimInBridgeTransfer(nextInTransferId);
    }

    function test_RevertWhen_CallerNotController() public {
        vm.expectRevert(Errors.NotController.selector);
        bridgeAdapter1.claimInBridgeTransfer(0);
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        uint256 nextInTransferId = bridgeAdapter1.nextInTransferId();

        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.claimInBridgeTransfer(nextInTransferId);
    }

    function test_ClaimInBridgeTransfer() public {
        uint256 inputAmount = 1e18;
        uint256 outputAmount = 999e15;

        uint256 nextInTransferId = bridgeAdapter1.nextInTransferId();

        _receiveInBridgeTransfer(
            address(bridgeAdapter1),
            abi.encode(
                IBridgeAdapter.BridgeMessage(
                    nextInTransferId,
                    address(bridgeAdapter2),
                    address(bridgeAdapter1),
                    chainId2,
                    block.chainid,
                    address(token2),
                    inputAmount,
                    address(token1),
                    outputAmount
                )
            ),
            address(token1),
            outputAmount
        );

        vm.expectEmit(false, false, false, true, address(bridgeController1));
        emit MockMachineEndpoint.ManageTransfer(address(token1), outputAmount, abi.encode(chainId2, inputAmount, false));

        vm.expectEmit(true, false, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.InBridgeTransferClaimed(nextInTransferId);

        vm.prank(address(bridgeController1));
        bridgeAdapter1.claimInBridgeTransfer(nextInTransferId);

        assertEq(IERC20(address(token1)).balanceOf(address(bridgeController1)), outputAmount);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeAdapter1)), 0);
        assertEq(bridgeAdapter1.nextInTransferId(), nextInTransferId + 1);
    }
}
