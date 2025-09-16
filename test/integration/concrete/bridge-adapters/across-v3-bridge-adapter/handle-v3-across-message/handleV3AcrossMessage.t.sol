// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

import {AcrossV3BridgeAdapter} from "src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";

import {AcrossV3BridgeAdapter_Integration_Concrete_Test} from "../AcrossV3BridgeAdapter.t.sol";

contract HandleV3AcrossMessage_AcrossV3BridgeAdapter_Integration_Concrete_Test is
    AcrossV3BridgeAdapter_Integration_Concrete_Test
{
    AcrossV3BridgeAdapter public acrossV3BridgeAdapter1;
    AcrossV3BridgeAdapter public acrossV3BridgeAdapter2;

    function setUp() public virtual override {
        AcrossV3BridgeAdapter_Integration_Concrete_Test.setUp();

        acrossV3BridgeAdapter1 = AcrossV3BridgeAdapter(address(bridgeAdapter1));
        acrossV3BridgeAdapter2 = AcrossV3BridgeAdapter(address(bridgeAdapter2));
    }

    function test_RevertWhen_CallerNotAuthorizedSource() public {
        vm.expectRevert(Errors.UnauthorizedSource.selector);
        acrossV3BridgeAdapter1.handleV3AcrossMessage(address(token1), 0, address(0), "");
    }

    function test_RevertWhen_UnexpectedMessage() public {
        vm.expectRevert(Errors.UnexpectedMessage.selector);
        vm.prank(address(acrossV3SpokePool));
        acrossV3BridgeAdapter1.handleV3AcrossMessage(address(token1), 0, address(0), "");
    }

    function test_RevertWhen_InvalidRecipientChainId() public {
        bytes memory encodedMessage =
            abi.encode(IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, 0, address(0), 0, address(0), 0));

        vm.prank(address(bridgeController1));
        acrossV3BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.InvalidRecipientChainId.selector);
        vm.prank(address(acrossV3SpokePool));
        acrossV3BridgeAdapter1.handleV3AcrossMessage(address(0), 0, address(0), encodedMessage);
    }

    function test_RevertWhen_InvalidOutputToken() public {
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(0), 0)
        );

        vm.prank(address(bridgeController1));
        acrossV3BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.InvalidOutputToken.selector);
        vm.prank(address(acrossV3SpokePool));
        acrossV3BridgeAdapter1.handleV3AcrossMessage(address(token1), 0, address(0), encodedMessage);
    }

    function test_RevertWhen_MaxValueLossExceeded() public {
        // case 1: received amount is smaller than message's minOutputAmount
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(0), 1)
        );

        vm.prank(address(bridgeController1));
        acrossV3BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        vm.prank(address(acrossV3SpokePool));
        acrossV3BridgeAdapter1.handleV3AcrossMessage(address(0), 0, address(0), encodedMessage);

        // case 2: delta between received amount and message's inputAmount is exceeds max bridge loss
        encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 1e18, address(0), 0)
        );

        vm.prank(address(bridgeController1));
        acrossV3BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        vm.prank(address(acrossV3SpokePool));
        acrossV3BridgeAdapter1.handleV3AcrossMessage(address(0), 0, address(0), encodedMessage);
    }

    function testRevertWhen_InvalidInputAmount() public {
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(0), 1)
        );

        vm.prank(address(bridgeController1));
        acrossV3BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.InvalidInputAmount.selector);
        vm.prank(address(acrossV3SpokePool));
        acrossV3BridgeAdapter1.handleV3AcrossMessage(address(0), 1, address(0), encodedMessage);
    }

    function test_HandleV3AcrossMessage() public {
        uint256 nextInTransferId = acrossV3BridgeAdapter1.nextInTransferId();
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(0), 0)
        );

        vm.prank(address(bridgeController1));
        acrossV3BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectEmit(true, false, false, false, address(acrossV3BridgeAdapter1));
        emit IBridgeAdapter.InBridgeTransferReceived(nextInTransferId);
        vm.prank(address(acrossV3SpokePool));
        acrossV3BridgeAdapter1.handleV3AcrossMessage(address(0), 0, address(0), encodedMessage);

        assertEq(bridgeAdapter1.nextInTransferId(), nextInTransferId + 1);
    }
}
