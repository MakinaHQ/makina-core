// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

import {LayerZeroV2BridgeAdapter} from "src/bridge/adapters/LayerZeroV2BridgeAdapter.sol";
import {MockOFTAdapter} from "test/mocks/MockOFTAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeAdapter_Integration_Concrete_Test} from "../LayerZeroV2BridgeAdapter.t.sol";

contract LzCompose_LayerZeroV2BridgeAdapter_Integration_Concrete_Test is
    LayerZeroV2BridgeAdapter_Integration_Concrete_Test
{
    LayerZeroV2BridgeAdapter internal layerZeroV2BridgeAdapter1;
    LayerZeroV2BridgeAdapter internal layerZeroV2BridgeAdapter2;

    function setUp() public virtual override {
        LayerZeroV2BridgeAdapter_Integration_Concrete_Test.setUp();

        layerZeroV2BridgeAdapter1 = LayerZeroV2BridgeAdapter(payable(address(bridgeAdapter1)));
        layerZeroV2BridgeAdapter2 = LayerZeroV2BridgeAdapter(payable(address(bridgeAdapter1)));
    }

    function test_RevertWhen_CallerNotAuthorizedSource() public {
        vm.expectRevert(Errors.UnauthorizedSource.selector);
        layerZeroV2BridgeAdapter1.lzCompose(address(mockOftAdapter), bytes32(0), "", address(0), "");
    }

    function test_RevertWhen_InvalidOft() public {
        address mockOftAdapter2 = address(new MockOFTAdapter(address(token1), address(mockLzEndpointV2), address(this)));

        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(0), 0)
        );
        bytes memory oftComposeMsg = _encodeComposeMsg(0, encodedMessage);

        vm.prank(address(bridgeController1));
        layerZeroV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.InvalidOft.selector);
        vm.prank(address(mockLzEndpointV2));
        layerZeroV2BridgeAdapter1.lzCompose(mockOftAdapter2, bytes32(0), oftComposeMsg, address(0), "");
    }

    function test_RevertWhen_InsufficientBalance() public {
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(0), 0)
        );
        bytes memory oftComposeMsg = _encodeComposeMsg(1, encodedMessage);

        vm.prank(address(bridgeController1));
        layerZeroV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.InsufficientBalance.selector);
        vm.prank(address(mockLzEndpointV2));
        layerZeroV2BridgeAdapter1.lzCompose(address(mockOftAdapter), bytes32(0), oftComposeMsg, address(0), "");
    }

    function test_RevertWhen_UnexpectedMessage() public {
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(0), 0)
        );
        bytes memory oftComposeMsg = _encodeComposeMsg(0, encodedMessage);

        vm.expectRevert(Errors.UnexpectedMessage.selector);
        vm.prank(address(mockLzEndpointV2));
        layerZeroV2BridgeAdapter1.lzCompose(address(mockOftAdapter), bytes32(0), oftComposeMsg, address(0), "");
    }

    function test_RevertWhen_InvalidRecipientChainId() public {
        bytes memory encodedMessage =
            abi.encode(IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, 0, address(0), 0, address(0), 0));
        bytes memory oftComposeMsg = _encodeComposeMsg(0, encodedMessage);

        vm.prank(address(bridgeController1));
        layerZeroV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.InvalidRecipientChainId.selector);
        vm.prank(address(mockLzEndpointV2));
        layerZeroV2BridgeAdapter1.lzCompose(address(mockOftAdapter), bytes32(0), oftComposeMsg, address(0), "");
    }

    function test_RevertWhen_InvalidOutputToken() public {
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(1), 0, address(0), 0)
        );
        bytes memory oftComposeMsg = _encodeComposeMsg(0, encodedMessage);

        vm.prank(address(bridgeController1));
        layerZeroV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.InvalidOutputToken.selector);
        vm.prank(address(mockLzEndpointV2));
        layerZeroV2BridgeAdapter1.lzCompose(address(mockOftAdapter), bytes32(0), oftComposeMsg, address(0), "");
    }

    function test_RevertWhen_MaxValueLossExceeded() public {
        // case 1: received amount is smaller than message's minOutputAmount
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(token1), 1)
        );
        bytes memory oftComposeMsg = _encodeComposeMsg(0, encodedMessage);

        vm.prank(address(bridgeController1));
        layerZeroV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        vm.prank(address(mockLzEndpointV2));
        layerZeroV2BridgeAdapter1.lzCompose(address(mockOftAdapter), bytes32(0), oftComposeMsg, address(0), "");

        // case 2: delta between received amount and message's inputAmount exceeds max bridge loss
        encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 1e18, address(token1), 0)
        );
        oftComposeMsg = _encodeComposeMsg(0, encodedMessage);

        vm.prank(address(bridgeController1));
        layerZeroV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        vm.prank(address(mockLzEndpointV2));
        layerZeroV2BridgeAdapter1.lzCompose(address(mockOftAdapter), bytes32(0), oftComposeMsg, address(0), "");
    }

    function test_RevertWhen_InvalidInputAmount() public {
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(token1), 1)
        );
        bytes memory oftComposeMsg = _encodeComposeMsg(1, encodedMessage);

        vm.prank(address(bridgeController1));
        layerZeroV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        deal(address(token1), address(layerZeroV2BridgeAdapter1), 1, true);

        vm.expectRevert(Errors.InvalidInputAmount.selector);
        vm.prank(address(mockLzEndpointV2));
        layerZeroV2BridgeAdapter1.lzCompose(address(mockOftAdapter), bytes32(0), oftComposeMsg, address(0), "");
    }

    function test_LzCompose() public {
        uint256 inputAmount = 1e18;
        uint256 nextInTransferId = layerZeroV2BridgeAdapter1.nextInTransferId();
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                0, address(0), address(0), 0, chainId1, address(0), inputAmount, address(token1), 0
            )
        );
        bytes memory oftComposeMsg = _encodeComposeMsg(inputAmount, encodedMessage);

        vm.prank(address(bridgeController1));
        layerZeroV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        deal(address(token1), address(layerZeroV2BridgeAdapter1), inputAmount, true);

        vm.expectEmit(true, false, false, false, address(layerZeroV2BridgeAdapter1));
        emit IBridgeAdapter.InBridgeTransferReceived(nextInTransferId);
        vm.prank(address(mockLzEndpointV2));
        layerZeroV2BridgeAdapter1.lzCompose(address(mockOftAdapter), bytes32(0), oftComposeMsg, address(0), "");

        assertEq(bridgeAdapter1.nextInTransferId(), nextInTransferId + 1);
    }
}
