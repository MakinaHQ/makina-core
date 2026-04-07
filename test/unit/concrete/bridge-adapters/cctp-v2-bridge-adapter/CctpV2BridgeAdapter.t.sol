// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

import {AuthorizeInBridgeTransfer_Integration_Concrete_Test} from
    "../bridge-adapter/authorize-in-bridge-transfer/authorizeInBridgeTransfer.t.sol";
import {BridgeAdapter_Unit_Concrete_Test} from "../bridge-adapter/BridgeAdapter.t.sol";

abstract contract CctpV2BridgeAdapter_Unit_Concrete_Test is BridgeAdapter_Unit_Concrete_Test {
    address internal tokenMessenger;
    address internal messageTransmitter;

    function setUp() public virtual override {
        BridgeAdapter_Unit_Concrete_Test.setUp();

        tokenMessenger = makeAddr("tokenMessenger");
        messageTransmitter = makeAddr("messageTransmitter");

        address beacon = address(_deployCctpV2BridgeAdapterBeacon(dao, address(0), tokenMessenger, messageTransmitter));
        bridgeAdapter = IBridgeAdapter(
            address(new BeaconProxy(beacon, abi.encodeCall(IBridgeAdapter.initialize, (address(controller), ""))))
        );
    }
}

contract Getters_CctpV2BridgeAdapter_Unit_Concrete_Test is CctpV2BridgeAdapter_Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(bridgeAdapter.controller(), address(controller));
        assertEq(bridgeAdapter.bridgeId(), CCTP_V2_BRIDGE_ID);
        assertEq(bridgeAdapter.approvalTarget(), tokenMessenger);
        assertEq(bridgeAdapter.executionTarget(), tokenMessenger);
        assertEq(bridgeAdapter.receiveSource(), messageTransmitter);
        assertEq(bridgeAdapter.nextOutTransferId(), 1);
        assertEq(bridgeAdapter.nextInTransferId(), 1);
    }
}

contract AuthorizeInBridgeTransfer_CctpV2BridgeAdapter_Unit_Concrete_Test is
    CctpV2BridgeAdapter_Unit_Concrete_Test,
    AuthorizeInBridgeTransfer_Integration_Concrete_Test
{
    function setUp()
        public
        override(CctpV2BridgeAdapter_Unit_Concrete_Test, AuthorizeInBridgeTransfer_Integration_Concrete_Test)
    {
        AuthorizeInBridgeTransfer_Integration_Concrete_Test.setUp();
        CctpV2BridgeAdapter_Unit_Concrete_Test.setUp();
    }
}
