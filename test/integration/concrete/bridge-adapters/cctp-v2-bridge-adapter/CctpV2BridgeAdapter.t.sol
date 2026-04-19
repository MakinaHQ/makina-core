// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {CctpV2BridgeAdapter} from "src/bridge/adapters/CctpV2BridgeAdapter.sol";
import {CctpV2BridgeConfig} from "src/bridge/configs/CctpV2BridgeConfig.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {MockCctpV2TokenMessenger} from "test/mocks/MockCctpV2TokenMessenger.sol";
import {MockCctpV2MessageTransmitter} from "test/mocks/MockCctpV2MessageTransmitter.sol";
import {MockCctpV2TokenMinter} from "test/mocks/MockCctpV2TokenMinter.sol";

import {
    ScheduleOutBridgeTransfer_Integration_Concrete_Test
} from "../bridge-adapter/schedule-out-bridge-transfer/scheduleOutBridgeTransfer.t.sol";
import {
    ClaimInBridgeTransfer_Integration_Concrete_Test
} from "../bridge-adapter/claim-in-bridge-transfer/claimInBridgeTransfer.t.sol";
import {BridgeAdapter_Integration_Concrete_Test} from "../bridge-adapter/BridgeAdapter.t.sol";
import {
    WithdrawPendingFunds_Integration_Concrete_Test
} from "../bridge-adapter/withdraw-pending-funds/withdrawPendingFunds.t.sol";

abstract contract CctpV2BridgeAdapter_Integration_Concrete_Test is BridgeAdapter_Integration_Concrete_Test {
    MockCctpV2TokenMessenger internal tokenMessenger;
    MockCctpV2MessageTransmitter internal messageTransmitter;
    MockCctpV2TokenMinter internal tokenMinter;

    uint256 internal cctpAttesterPrivateKey;
    address internal cctpAttester;
    address internal cctpFeeReceiver;

    function setUp() public virtual override {
        BridgeAdapter_Integration_Concrete_Test.setUp();

        bridgeController1.setMaxBridgeLossBps(CCTP_V2_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS);
        bridgeController2.setMaxBridgeLossBps(CCTP_V2_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS);

        CctpV2BridgeConfig config = _deployCctpV2BridgeConfig(address(accessManager), address(accessManager));
        coreRegistry.setBridgeConfig(CCTP_V2_BRIDGE_ID, address(config));
        config.setCctpDomain(chainId2, CCTP_V2_SPOKE_DOMAIN);
        config.setForeignToken(address(token1), chainId2, address(token2));

        setupAccessManagerRolesAndOwnership();

        (cctpAttester, cctpAttesterPrivateKey) = makeAddrAndKey("cctpAttester");
        cctpFeeReceiver = makeAddr("cctpFeeReceiver");

        tokenMinter = new MockCctpV2TokenMinter();
        tokenMessenger = new MockCctpV2TokenMessenger(address(tokenMinter), 0, cctpFeeReceiver);
        messageTransmitter = new MockCctpV2MessageTransmitter(cctpAttester);

        tokenMinter.setLocalTokenMessenger(address(tokenMessenger));
        tokenMinter.setLocalToken(CCTP_V2_SPOKE_DOMAIN, bytes32(uint256(uint160(address(token2)))), address(token1));
        tokenMinter.setLocalToken(CCTP_V2_HUB_DOMAIN, bytes32(uint256(uint160(address(token1)))), address(token2));

        address beacon = address(
            _deployCctpV2BridgeAdapterBeacon(
                address(accessManager), address(coreRegistry), address(tokenMessenger), address(messageTransmitter)
            )
        );

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
        address,
        uint256 receivedAmount
    ) internal virtual override {
        vm.prank(IBridgeAdapter(bridgeAdapter).controller());
        IBridgeAdapter(bridgeAdapter).authorizeInBridgeTransfer(keccak256(encodedMessage));

        bool receiverSide1 = bridgeAdapter == address(bridgeAdapter1);

        bytes32 mintRecipient = bytes32(uint256(uint160(bridgeAdapter)));
        address burnToken = abi.decode(encodedMessage, (IBridgeAdapter.BridgeMessage)).inputToken;

        bytes32 sender = receiverSide1
            ? bytes32(uint256(uint160(address(bridgeAdapter2))))
            : bytes32(uint256(uint160(address(bridgeAdapter1))));

        bytes memory cctpMessage = tokenMessenger.formatMessageForRelay(
            MockCctpV2TokenMessenger.RelayMessageParams({
                sourceDomain: receiverSide1 ? CCTP_V2_SPOKE_DOMAIN : CCTP_V2_HUB_DOMAIN,
                destinationDomain: receiverSide1 ? CCTP_V2_HUB_DOMAIN : CCTP_V2_SPOKE_DOMAIN,
                recipient: bytes32(uint256(uint160(address(tokenMessenger)))),
                destinationCaller: mintRecipient,
                minFinalityThreshold: CCTP_V2_CONFIRMED_FINALITY_THRESHOLD,
                burnToken: burnToken,
                mintRecipient: mintRecipient,
                amount: receivedAmount,
                sender: sender,
                maxFee: 0,
                feeExecuted: 0,
                hookData: encodedMessage
            })
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(cctpAttesterPrivateKey, keccak256(cctpMessage));
        bytes memory attestation = abi.encodePacked(r, s, v);

        CctpV2BridgeAdapter(bridgeAdapter).receiveCctpV2Message(cctpMessage, attestation);
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId) internal virtual override {
        if (bridgeAdapter == address(bridgeAdapter1)) {
            tokenMessenger.setSourceDomain(CCTP_V2_HUB_DOMAIN);
        } else {
            tokenMessenger.setSourceDomain(CCTP_V2_SPOKE_DOMAIN);
        }

        vm.prank(IBridgeAdapter(bridgeAdapter).controller());
        IBridgeAdapter(bridgeAdapter).sendOutBridgeTransfer(transferId, abi.encode(uint32(1000)));
    }
}

contract ScheduleOutBridgeTransfer_CctpV2BridgeAdapter_Integration_Concrete_Test is
    ScheduleOutBridgeTransfer_Integration_Concrete_Test,
    CctpV2BridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(CctpV2BridgeAdapter_Integration_Concrete_Test, ScheduleOutBridgeTransfer_Integration_Concrete_Test)
    {
        CctpV2BridgeAdapter_Integration_Concrete_Test.setUp();
        ScheduleOutBridgeTransfer_Integration_Concrete_Test.setUp();
    }

    function _receiveInBridgeTransfer(
        address bridgeAdapter,
        bytes memory encodedMessage,
        address receivedToken,
        uint256 receivedAmount
    ) internal override(CctpV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test) {
        CctpV2BridgeAdapter_Integration_Concrete_Test._receiveInBridgeTransfer(
            bridgeAdapter, encodedMessage, receivedToken, receivedAmount
        );
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId)
        internal
        override(CctpV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test)
    {
        CctpV2BridgeAdapter_Integration_Concrete_Test._sendOutBridgeTransfer(bridgeAdapter, transferId);
    }
}

contract ClaimInBridgeTransfer_CctpV2BridgeAdapter_Integration_Concrete_Test is
    ClaimInBridgeTransfer_Integration_Concrete_Test,
    CctpV2BridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(CctpV2BridgeAdapter_Integration_Concrete_Test, ClaimInBridgeTransfer_Integration_Concrete_Test)
    {
        CctpV2BridgeAdapter_Integration_Concrete_Test.setUp();
        ClaimInBridgeTransfer_Integration_Concrete_Test.setUp();
    }

    function _receiveInBridgeTransfer(
        address bridgeAdapter,
        bytes memory encodedMessage,
        address receivedToken,
        uint256 receivedAmount
    ) internal override(CctpV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test) {
        CctpV2BridgeAdapter_Integration_Concrete_Test._receiveInBridgeTransfer(
            bridgeAdapter, encodedMessage, receivedToken, receivedAmount
        );
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId)
        internal
        override(CctpV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test)
    {
        CctpV2BridgeAdapter_Integration_Concrete_Test._sendOutBridgeTransfer(bridgeAdapter, transferId);
    }
}

contract WithdrawPendingFunds_CctpV2BridgeAdapter_Integration_Concrete_Test is
    WithdrawPendingFunds_Integration_Concrete_Test,
    CctpV2BridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(CctpV2BridgeAdapter_Integration_Concrete_Test, WithdrawPendingFunds_Integration_Concrete_Test)
    {
        CctpV2BridgeAdapter_Integration_Concrete_Test.setUp();
        WithdrawPendingFunds_Integration_Concrete_Test.setUp();
    }

    function _receiveInBridgeTransfer(
        address bridgeAdapter,
        bytes memory encodedMessage,
        address receivedToken,
        uint256 receivedAmount
    ) internal override(CctpV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test) {
        CctpV2BridgeAdapter_Integration_Concrete_Test._receiveInBridgeTransfer(
            bridgeAdapter, encodedMessage, receivedToken, receivedAmount
        );
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId)
        internal
        override(CctpV2BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test)
    {
        CctpV2BridgeAdapter_Integration_Concrete_Test._sendOutBridgeTransfer(bridgeAdapter, transferId);
    }
}
