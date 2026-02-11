// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {LayerZeroV2BridgeAdapter} from "src/bridge/adapters/LayerZeroV2BridgeAdapter.sol";
import {LayerZeroV2BridgeConfig} from "src/bridge/configs/LayerZeroV2BridgeConfig.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {MockLzSendLib} from "test/mocks/MockLzSendLib.sol";
import {MockOFTAdapter} from "test/mocks/MockOFTAdapter.sol";
import {MockOFT} from "test/mocks/MockOFT.sol";

import {ScheduleOutBridgeTransfer_Integration_Concrete_Test} from
    "../bridge-adapter/schedule-out-bridge-transfer/scheduleOutBridgeTransfer.t.sol";
import {ClaimInBridgeTransfer_Integration_Concrete_Test} from
    "../bridge-adapter/claim-in-bridge-transfer/claimInBridgeTransfer.t.sol";
import {BridgeAdapter_Integration_Concrete_Test} from "../bridge-adapter/BridgeAdapter.t.sol";
import {WithdrawPendingFunds_Integration_Concrete_Test} from
    "../bridge-adapter/withdraw-pending-funds/withdrawPendingFunds.t.sol";

abstract contract LayerZeroV2BridgeAdapter_Integration_Concrete_Test is BridgeAdapter_Integration_Concrete_Test {
    MockLzSendLib internal mockLzSendLib;
    ILayerZeroEndpointV2 internal mockLzEndpointV2;

    LayerZeroV2BridgeConfig internal lzConfig;

    MockOFTAdapter internal mockOftAdapter;
    MockOFT internal mockOft;

    function setUp() public virtual override {
        BridgeAdapter_Integration_Concrete_Test.setUp();

        bridgeController1.setMaxBridgeLossBps(LAYER_ZERO_V2_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS);
        bridgeController2.setMaxBridgeLossBps(LAYER_ZERO_V2_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS);

        mockLzEndpointV2 = ILayerZeroEndpointV2(
            _deployCode(abi.encodePacked(getMockLayerZeroEndpointV2Code(), abi.encode(0, address(this))), 0)
        );
        mockLzSendLib = new MockLzSendLib();
        mockLzEndpointV2.registerLibrary(address(mockLzSendLib));
        mockLzEndpointV2.setDefaultSendLibrary(LAYER_ZERO_V2_SPOKE_CHAIN_ID, address(mockLzSendLib));

        mockOftAdapter = new MockOFTAdapter(address(token1), address(mockLzEndpointV2), address(this));
        mockOftAdapter.setPeer(LAYER_ZERO_V2_SPOKE_CHAIN_ID, OFTComposeMsgCodec.addressToBytes32(address(0x1)));

        mockOft = new MockOFT("Mock OFT", "MOFT", address(mockLzEndpointV2), address(this));
        mockOft.setPeer(LAYER_ZERO_V2_SPOKE_CHAIN_ID, OFTComposeMsgCodec.addressToBytes32(address(0x2)));

        address beacon = address(
            _deployLayerZeroV2BridgeAdapterBeacon(
                address(accessManager), address(coreRegistry), address(mockLzEndpointV2)
            )
        );

        lzConfig = _deployLayerZeroV2BridgeConfig(address(accessManager), address(accessManager));
        ICoreRegistry(coreRegistry).setBridgeConfig(LAYER_ZERO_V2_BRIDGE_ID, address(lzConfig));
        lzConfig.setLzChainId(chainId2, LAYER_ZERO_V2_SPOKE_CHAIN_ID);
        lzConfig.setOft(address(mockOftAdapter));
        lzConfig.setOft(address(mockOft));
        lzConfig.setForeignToken(address(token1), chainId2, address(token2));
        lzConfig.setForeignToken(address(mockOft), chainId2, address(token3));

        setupAccessManagerRolesAndOwnership();

        bridgeAdapter1 = IBridgeAdapter(
            address(
                new BeaconProxy(beacon, abi.encodeCall(IBridgeAdapter.initialize, (address(bridgeController1), "")))
            )
        );
        bridgeAdapter2 = IBridgeAdapter(
            address(
                new BeaconProxy(beacon, abi.encodeCall(IBridgeAdapter.initialize, (address(bridgeController2), "")))
            )
        );
    }

    function _receiveInBridgeTransfer(
        address bridgeAdapter,
        bytes memory encodedMessage,
        address receivedToken,
        uint256 receivedAmount
    ) internal virtual override {
        vm.prank(IBridgeAdapter(bridgeAdapter).controller());
        IBridgeAdapter(bridgeAdapter).authorizeInBridgeTransfer(keccak256(encodedMessage));

        deal(
            receivedToken,
            address(bridgeAdapter),
            IERC20(receivedToken).balanceOf(address(bridgeAdapter)) + receivedAmount,
            true
        );

        address oft = lzConfig.tokenToOft(receivedToken);

        bytes memory oftComposeMsg = _encodeComposeMsg(receivedAmount, encodedMessage);

        vm.prank(address(mockLzEndpointV2));
        LayerZeroV2BridgeAdapter(payable(bridgeAdapter)).lzCompose(oft, bytes32(0), oftComposeMsg, address(0), "");
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId) internal virtual override {
        vm.prank(IBridgeAdapter(bridgeAdapter).controller());
        IBridgeAdapter(bridgeAdapter).sendOutBridgeTransfer(
            transferId, abi.encode(uint128(0), uint128(0), uint256(type(uint256).max))
        );
    }

    function _encodeComposeMsg(uint256 receivedAmount, bytes memory encodedMessage)
        internal
        view
        returns (bytes memory)
    {
        bytes memory oftMsg = abi.encodePacked(OFTComposeMsgCodec.addressToBytes32(address(this)), encodedMessage);
        return OFTComposeMsgCodec.encode(0, 0, receivedAmount, oftMsg);
    }
}

contract ScheduleOutBridgeTransfer_LayerZeroV2BridgeAdapter_Integration_Concrete_Test is
    ScheduleOutBridgeTransfer_Integration_Concrete_Test,
    LayerZeroV2BridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(LayerZeroV2BridgeAdapter_Integration_Concrete_Test, ScheduleOutBridgeTransfer_Integration_Concrete_Test)
    {
        LayerZeroV2BridgeAdapter_Integration_Concrete_Test.setUp();
        ScheduleOutBridgeTransfer_Integration_Concrete_Test.setUp();
    }

    function _receiveInBridgeTransfer(
        address bridgeAdapter,
        bytes memory encodedMessage,
        address receivedToken,
        uint256 receivedAmount
    ) internal override(LayerZeroV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test) {
        LayerZeroV2BridgeAdapter_Integration_Concrete_Test._receiveInBridgeTransfer(
            bridgeAdapter, encodedMessage, receivedToken, receivedAmount
        );
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId)
        internal
        override(LayerZeroV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test)
    {
        LayerZeroV2BridgeAdapter_Integration_Concrete_Test._sendOutBridgeTransfer(bridgeAdapter, transferId);
    }
}

contract ClaimInBridgeTransfer_LayerZeroV2BridgeAdapter_Integration_Concrete_Test is
    ClaimInBridgeTransfer_Integration_Concrete_Test,
    LayerZeroV2BridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(LayerZeroV2BridgeAdapter_Integration_Concrete_Test, ClaimInBridgeTransfer_Integration_Concrete_Test)
    {
        LayerZeroV2BridgeAdapter_Integration_Concrete_Test.setUp();
        ClaimInBridgeTransfer_Integration_Concrete_Test.setUp();
    }

    function _receiveInBridgeTransfer(
        address bridgeAdapter,
        bytes memory encodedMessage,
        address receivedToken,
        uint256 receivedAmount
    ) internal override(LayerZeroV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test) {
        LayerZeroV2BridgeAdapter_Integration_Concrete_Test._receiveInBridgeTransfer(
            bridgeAdapter, encodedMessage, receivedToken, receivedAmount
        );
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId)
        internal
        override(LayerZeroV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test)
    {
        LayerZeroV2BridgeAdapter_Integration_Concrete_Test._sendOutBridgeTransfer(bridgeAdapter, transferId);
    }
}

contract WithdrawPendingFunds_LayerZeroV2BridgeAdapter_Integration_Concrete_Test is
    WithdrawPendingFunds_Integration_Concrete_Test,
    LayerZeroV2BridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(LayerZeroV2BridgeAdapter_Integration_Concrete_Test, WithdrawPendingFunds_Integration_Concrete_Test)
    {
        LayerZeroV2BridgeAdapter_Integration_Concrete_Test.setUp();
        WithdrawPendingFunds_Integration_Concrete_Test.setUp();
    }

    function _receiveInBridgeTransfer(
        address bridgeAdapter,
        bytes memory encodedMessage,
        address receivedToken,
        uint256 receivedAmount
    ) internal override(LayerZeroV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test) {
        LayerZeroV2BridgeAdapter_Integration_Concrete_Test._receiveInBridgeTransfer(
            bridgeAdapter, encodedMessage, receivedToken, receivedAmount
        );
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId)
        internal
        override(LayerZeroV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test)
    {
        LayerZeroV2BridgeAdapter_Integration_Concrete_Test._sendOutBridgeTransfer(bridgeAdapter, transferId);
    }
}
