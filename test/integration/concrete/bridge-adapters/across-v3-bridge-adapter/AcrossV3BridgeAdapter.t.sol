// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {AcrossV3BridgeAdapter} from "src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IMockAcrossV3SpokePool} from "test/mocks/IMockAcrossV3SpokePool.sol";

import {ScheduleOutBridgeTransfer_Integration_Concrete_Test} from
    "../bridge-adapter/schedule-out-bridge-transfer/scheduleOutBridgeTransfer.t.sol";
import {ClaimInBridgeTransfer_Integration_Concrete_Test} from
    "../bridge-adapter/claim-in-bridge-transfer/claimInBridgeTransfer.t.sol";
import {BridgeAdapter_Integration_Concrete_Test} from "../bridge-adapter/BridgeAdapter.t.sol";
import {WithdrawPendingFunds_Integration_Concrete_Test} from
    "../bridge-adapter/withdraw-pending-funds/withdrawPendingFunds.t.sol";

abstract contract AcrossV3BridgeAdapter_Integration_Concrete_Test is BridgeAdapter_Integration_Concrete_Test {
    IMockAcrossV3SpokePool public acrossV3SpokePool;

    function setUp() public virtual override {
        BridgeAdapter_Integration_Concrete_Test.setUp();

        acrossV3SpokePool = IMockAcrossV3SpokePool(deployMockAcrossV3SpokePoolViaIR());

        address beacon = address(_deployAcrossV3BridgeAdapterBeacon(dao, address(acrossV3SpokePool)));
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

        vm.prank(address(acrossV3SpokePool));
        AcrossV3BridgeAdapter(bridgeAdapter).handleV3AcrossMessage(
            receivedToken, receivedAmount, address(0), encodedMessage
        );
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId) internal virtual override {
        vm.prank(IBridgeAdapter(bridgeAdapter).controller());
        IBridgeAdapter(bridgeAdapter).sendOutBridgeTransfer(transferId, abi.encode(1 hours));
    }
}

contract ScheduleOutBridgeTransfer_AcrossV3BridgeAdapter_Integration_Concrete_Test is
    ScheduleOutBridgeTransfer_Integration_Concrete_Test,
    AcrossV3BridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(AcrossV3BridgeAdapter_Integration_Concrete_Test, ScheduleOutBridgeTransfer_Integration_Concrete_Test)
    {
        AcrossV3BridgeAdapter_Integration_Concrete_Test.setUp();
        ScheduleOutBridgeTransfer_Integration_Concrete_Test.setUp();
    }

    function _receiveInBridgeTransfer(
        address bridgeAdapter,
        bytes memory encodedMessage,
        address receivedToken,
        uint256 receivedAmount
    ) internal override(AcrossV3BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test) {
        AcrossV3BridgeAdapter_Integration_Concrete_Test._receiveInBridgeTransfer(
            bridgeAdapter, encodedMessage, receivedToken, receivedAmount
        );
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId)
        internal
        override(AcrossV3BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test)
    {
        AcrossV3BridgeAdapter_Integration_Concrete_Test._sendOutBridgeTransfer(bridgeAdapter, transferId);
    }
}

contract ClaimInBridgeTransfer_AcrossV3BridgeAdapter_Integration_Concrete_Test is
    ClaimInBridgeTransfer_Integration_Concrete_Test,
    AcrossV3BridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(AcrossV3BridgeAdapter_Integration_Concrete_Test, ClaimInBridgeTransfer_Integration_Concrete_Test)
    {
        AcrossV3BridgeAdapter_Integration_Concrete_Test.setUp();
        ClaimInBridgeTransfer_Integration_Concrete_Test.setUp();
    }

    function _receiveInBridgeTransfer(
        address bridgeAdapter,
        bytes memory encodedMessage,
        address receivedToken,
        uint256 receivedAmount
    ) internal override(AcrossV3BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test) {
        AcrossV3BridgeAdapter_Integration_Concrete_Test._receiveInBridgeTransfer(
            bridgeAdapter, encodedMessage, receivedToken, receivedAmount
        );
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId)
        internal
        override(AcrossV3BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test)
    {
        AcrossV3BridgeAdapter_Integration_Concrete_Test._sendOutBridgeTransfer(bridgeAdapter, transferId);
    }
}

contract WithdrawPendingFunds_AcrossV3BridgeAdapter_Integration_Concrete_Test is
    WithdrawPendingFunds_Integration_Concrete_Test,
    AcrossV3BridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(AcrossV3BridgeAdapter_Integration_Concrete_Test, WithdrawPendingFunds_Integration_Concrete_Test)
    {
        AcrossV3BridgeAdapter_Integration_Concrete_Test.setUp();
        WithdrawPendingFunds_Integration_Concrete_Test.setUp();
    }

    function _receiveInBridgeTransfer(
        address bridgeAdapter,
        bytes memory encodedMessage,
        address receivedToken,
        uint256 receivedAmount
    ) internal override(AcrossV3BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test) {
        AcrossV3BridgeAdapter_Integration_Concrete_Test._receiveInBridgeTransfer(
            bridgeAdapter, encodedMessage, receivedToken, receivedAmount
        );
    }

    function _sendOutBridgeTransfer(address bridgeAdapter, uint256 transferId)
        internal
        override(AcrossV3BridgeAdapter_Integration_Concrete_Test, BridgeAdapter_Integration_Concrete_Test)
    {
        AcrossV3BridgeAdapter_Integration_Concrete_Test._sendOutBridgeTransfer(bridgeAdapter, transferId);
    }
}
