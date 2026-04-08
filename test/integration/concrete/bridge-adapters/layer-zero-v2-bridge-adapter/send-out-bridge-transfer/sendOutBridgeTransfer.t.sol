// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {LayerZeroV2BridgeAdapter} from "src/bridge/adapters/LayerZeroV2BridgeAdapter.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockOFT} from "test/mocks/MockOFT.sol";
import {MockOFTAdapter} from "test/mocks/MockOFTAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {LzOptionsBuilder} from "src/libraries/LzOptionsBuilder.sol";

import {LayerZeroV2BridgeAdapter_Integration_Concrete_Test} from "../LayerZeroV2BridgeAdapter.t.sol";

contract SendOutBridgeTransfer_LayerZeroV2BridgeAdapter_Integration_Concrete_Test is
    LayerZeroV2BridgeAdapter_Integration_Concrete_Test
{
    using LzOptionsBuilder for bytes;

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

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint128(0), uint128(0), 0));
    }

    function test_RevertWhen_CallerNotController() public {
        vm.expectRevert(Errors.NotController.selector);
        bridgeAdapter1.sendOutBridgeTransfer(0, abi.encode(uint128(0), uint128(0), 0));
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();
        uint256 inputAmount = 1e18;

        // transfer not sheduled
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint128(0), uint128(0), 0));

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));
        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(chainId2, address(0), address(token1), inputAmount, address(token2), 0);

        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint128(0), uint128(0), 0));

        // transfer already sent
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint128(0), uint128(0), 0));
    }

    function test_RevertWhen_ExceededMaxFee() public {
        mockLzSendLib.setVerifyGas(DEFAULT_LAYER_ZERO_V2_VERIFY_GAS);

        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(chainId2, address(0), address(token1), inputAmount, address(token2), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ExceededMaxFee.selector, DEFAULT_LAYER_ZERO_V2_VERIFY_GAS * DEFAULT_LAYER_ZERO_V2_GAS_PRICE, 0
            )
        );
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint128(0), uint128(0), 0));
    }

    function test_RevertWhen_UnsufficientGasBalance() public {
        mockLzSendLib.setVerifyGas(DEFAULT_LAYER_ZERO_V2_VERIFY_GAS);

        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(chainId2, address(0), address(token1), inputAmount, address(token2), 0);

        vm.expectRevert();
        bridgeAdapter1.sendOutBridgeTransfer(
            nextOutTransferId,
            abi.encode(uint128(0), uint128(0), DEFAULT_LAYER_ZERO_V2_VERIFY_GAS * DEFAULT_LAYER_ZERO_V2_GAS_PRICE)
        );
    }

    function test_RevertGiven_InvalidLzSentAmount() public {
        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(chainId2, address(0), address(token1), inputAmount, address(token2), 0);

        mockOftAdapter.setFaultyModeSend(true);

        vm.expectRevert(Errors.InvalidLzSentAmount.selector);
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint128(0), uint128(0), 0));
    }

    function test_RevertWhen_MaxValueLossExceeded() public {
        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(0), address(token1), inputAmount, address(token2), 1e18
        );

        mockOftAdapter.setFaultyModeReceive(true);

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint128(0), uint128(0), 0));
    }

    function test_SendOutBridgeTransfer_NativeOFT_WithoutGasOption() public {
        mockLzSendLib.setVerifyGas(DEFAULT_LAYER_ZERO_V2_VERIFY_GAS);

        uint256 extraGas = 20000;
        _fundBridgeAdapterGas(DEFAULT_LAYER_ZERO_V2_VERIFY_GAS, 0, 0, extraGas, DEFAULT_LAYER_ZERO_V2_GAS_PRICE);

        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                nextOutTransferId,
                address(bridgeAdapter1),
                address(bridgeAdapter2),
                block.chainid,
                chainId2,
                address(mockOft),
                inputAmount,
                address(token3),
                minOutputAmount
            )
        );

        mockOft.mint(address(bridgeController1), inputAmount);

        vm.startPrank(address(bridgeController1));

        mockOft.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(mockOft), inputAmount, address(token3), minOutputAmount
        );

        vm.expectEmit(false, false, false, true, address(mockOft));
        emit MockOFT.SentParams(
            LAYER_ZERO_V2_SPOKE_ENDPOINT_ID,
            OFTComposeMsgCodec.addressToBytes32(address(bridgeAdapter2)),
            inputAmount,
            inputAmount,
            encodedMessage,
            ""
        );

        vm.expectEmit(false, true, false, false, address(bridgeAdapter1));
        emit LayerZeroV2BridgeAdapter.LzGuidCreated(0, nextOutTransferId);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.OutBridgeTransferSent(nextOutTransferId);

        bridgeAdapter1.sendOutBridgeTransfer(
            nextOutTransferId,
            abi.encode(uint128(0), uint128(0), DEFAULT_LAYER_ZERO_V2_VERIFY_GAS * DEFAULT_LAYER_ZERO_V2_GAS_PRICE)
        );

        assertEq(IERC20(address(mockOft)).balanceOf(address(bridgeController1)), 0);
        assertEq(IERC20(address(mockOft)).balanceOf(address(bridgeAdapter1)), 0);
        assertEq(IERC20(address(mockOft)).totalSupply(), 0);
        assertEq(address(bridgeAdapter1).balance, extraGas * DEFAULT_LAYER_ZERO_V2_GAS_PRICE);
    }

    function test_SendOutBridgeTransfer_NativeOFT_WithGasOption() public {
        mockLzSendLib.setVerifyGas(DEFAULT_LAYER_ZERO_V2_VERIFY_GAS);
        mockLzSendLib.setLzReceiveGas(DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS);
        mockLzSendLib.setLzComposeGas(DEFAULT_LAYER_ZERO_V2_LZ_COMPOSE_GAS);

        uint256 extraGas = 20000;
        _fundBridgeAdapterGas(
            DEFAULT_LAYER_ZERO_V2_VERIFY_GAS,
            DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS,
            DEFAULT_LAYER_ZERO_V2_LZ_COMPOSE_GAS,
            extraGas,
            DEFAULT_LAYER_ZERO_V2_GAS_PRICE
        );

        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                nextOutTransferId,
                address(bridgeAdapter1),
                address(bridgeAdapter2),
                block.chainid,
                chainId2,
                address(mockOft),
                inputAmount,
                address(token3),
                minOutputAmount
            )
        );

        mockOft.mint(address(bridgeController1), inputAmount);

        vm.startPrank(address(bridgeController1));

        mockOft.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(mockOft), inputAmount, address(token3), minOutputAmount
        );

        bytes memory extraOptions = LzOptionsBuilder.newOptions().addExecutorLzReceiveOption(
            DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS
        ).addExecutorLzComposeOption(0, DEFAULT_LAYER_ZERO_V2_LZ_COMPOSE_GAS);

        vm.expectEmit(false, false, false, true, address(mockOft));
        emit MockOFT.SentParams(
            LAYER_ZERO_V2_SPOKE_ENDPOINT_ID,
            OFTComposeMsgCodec.addressToBytes32(address(bridgeAdapter2)),
            inputAmount,
            inputAmount,
            encodedMessage,
            extraOptions
        );

        vm.expectEmit(false, true, false, false, address(bridgeAdapter1));
        emit LayerZeroV2BridgeAdapter.LzGuidCreated(0, nextOutTransferId);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.OutBridgeTransferSent(nextOutTransferId);

        bridgeAdapter1.sendOutBridgeTransfer(
            nextOutTransferId,
            abi.encode(DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS, DEFAULT_LAYER_ZERO_V2_LZ_COMPOSE_GAS, type(uint256).max)
        );

        assertEq(IERC20(address(mockOft)).balanceOf(address(bridgeController1)), 0);
        assertEq(IERC20(address(mockOft)).balanceOf(address(bridgeAdapter1)), 0);
        assertEq(IERC20(address(mockOft)).totalSupply(), 0);
        assertEq(address(bridgeAdapter1).balance, extraGas * DEFAULT_LAYER_ZERO_V2_GAS_PRICE);
    }

    function test_SendOutBridgeTransfer_OFTAdapter_WithoutGasOption() public {
        mockLzSendLib.setVerifyGas(DEFAULT_LAYER_ZERO_V2_VERIFY_GAS);

        uint256 extraGas = 20000;
        _fundBridgeAdapterGas(DEFAULT_LAYER_ZERO_V2_VERIFY_GAS, 0, 0, extraGas, DEFAULT_LAYER_ZERO_V2_GAS_PRICE);

        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

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

        vm.expectEmit(false, false, false, false, address(mockOftAdapter));
        emit MockOFTAdapter.SentParams(
            LAYER_ZERO_V2_SPOKE_ENDPOINT_ID,
            OFTComposeMsgCodec.addressToBytes32(address(bridgeAdapter2)),
            inputAmount,
            inputAmount,
            encodedMessage,
            ""
        );

        vm.expectEmit(false, true, false, false, address(bridgeAdapter1));
        emit LayerZeroV2BridgeAdapter.LzGuidCreated(0, nextOutTransferId);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.OutBridgeTransferSent(nextOutTransferId);

        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint128(0), uint128(0), type(uint256).max));

        assertEq(IERC20(address(token1)).balanceOf(address(bridgeController1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeAdapter1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(mockOftAdapter)), inputAmount);
        assertEq(address(bridgeAdapter1).balance, extraGas * DEFAULT_LAYER_ZERO_V2_GAS_PRICE);
    }

    function test_SendOutBridgeTransfer_OFTAdapter_WithGasOption() public {
        mockLzSendLib.setVerifyGas(DEFAULT_LAYER_ZERO_V2_VERIFY_GAS);
        mockLzSendLib.setLzReceiveGas(DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS);
        mockLzSendLib.setLzComposeGas(DEFAULT_LAYER_ZERO_V2_LZ_COMPOSE_GAS);

        uint256 extraGas = 20000;
        _fundBridgeAdapterGas(
            DEFAULT_LAYER_ZERO_V2_VERIFY_GAS,
            DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS,
            DEFAULT_LAYER_ZERO_V2_LZ_COMPOSE_GAS,
            extraGas,
            DEFAULT_LAYER_ZERO_V2_GAS_PRICE
        );

        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = 999e15;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

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

        bytes memory extraOptions = LzOptionsBuilder.newOptions().addExecutorLzReceiveOption(
            DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS
        ).addExecutorLzComposeOption(0, DEFAULT_LAYER_ZERO_V2_LZ_COMPOSE_GAS);

        vm.expectEmit(false, false, false, true, address(mockOftAdapter));
        emit MockOFTAdapter.SentParams(
            LAYER_ZERO_V2_SPOKE_ENDPOINT_ID,
            OFTComposeMsgCodec.addressToBytes32(address(bridgeAdapter2)),
            inputAmount,
            inputAmount,
            encodedMessage,
            extraOptions
        );

        vm.expectEmit(false, true, false, false, address(bridgeAdapter1));
        emit LayerZeroV2BridgeAdapter.LzGuidCreated(0, nextOutTransferId);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.OutBridgeTransferSent(nextOutTransferId);

        bridgeAdapter1.sendOutBridgeTransfer(
            nextOutTransferId,
            abi.encode(DEFAULT_LAYER_ZERO_V2_LZ_RECEIVE_GAS, DEFAULT_LAYER_ZERO_V2_LZ_COMPOSE_GAS, type(uint256).max)
        );

        assertEq(IERC20(address(token1)).balanceOf(address(bridgeController1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeAdapter1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(mockOftAdapter)), inputAmount);
        assertEq(address(bridgeAdapter1).balance, extraGas * DEFAULT_LAYER_ZERO_V2_GAS_PRICE);
    }

    function _fundBridgeAdapterGas(
        uint256 verifyGas,
        uint128 lzReceiveGas,
        uint128 lzComposeGas,
        uint256 extraGas,
        uint256 gasPrice
    ) internal {
        uint256 totalValue = (verifyGas + lzReceiveGas + lzComposeGas + extraGas) * gasPrice;
        deal(address(this), totalValue);
        (bool success,) = payable(address(bridgeAdapter1)).call{value: totalValue}("");
        assertTrue(success);
    }
}
