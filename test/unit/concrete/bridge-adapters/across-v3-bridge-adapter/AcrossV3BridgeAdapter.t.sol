// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IMakinaContext} from "src/interfaces/IMakinaContext.sol";

import {AuthorizeInBridgeTransfer_Integration_Concrete_Test} from
    "../bridge-adapter/authorize-in-bridge-transfer/authorizeInBridgeTransfer.t.sol";
import {BridgeAdapter_Unit_Concrete_Test} from "../bridge-adapter/BridgeAdapter.t.sol";

abstract contract AcrossV3BridgeAdapter_Unit_Concrete_Test is BridgeAdapter_Unit_Concrete_Test {
    address internal acrossV3SpokePool;

    function setUp() public virtual override {
        BridgeAdapter_Unit_Concrete_Test.setUp();

        acrossV3SpokePool = makeAddr("acrossV3SpokePool");
        coreRegistry = makeAddr("coreRegistry");

        address beacon = address(_deployAcrossV3BridgeAdapterBeacon(dao, address(coreRegistry), acrossV3SpokePool));
        bridgeAdapter = IBridgeAdapter(
            address(new BeaconProxy(beacon, abi.encodeCall(IBridgeAdapter.initialize, (address(controller), ""))))
        );
    }
}

contract Getters_AcrossV3BridgeAdapter_Unit_Concrete_Test is AcrossV3BridgeAdapter_Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(IMakinaContext(address(bridgeAdapter)).registry(), address(coreRegistry));
        assertEq(bridgeAdapter.controller(), address(controller));
        assertEq(bridgeAdapter.bridgeId(), ACROSS_V3_BRIDGE_ID);
        assertEq(bridgeAdapter.approvalTarget(), acrossV3SpokePool);
        assertEq(bridgeAdapter.executionTarget(), acrossV3SpokePool);
        assertEq(bridgeAdapter.receiveSource(), acrossV3SpokePool);
        assertEq(bridgeAdapter.nextOutTransferId(), 1);
        assertEq(bridgeAdapter.nextInTransferId(), 1);
    }
}

contract AuthorizeInBridgeTransfer_AcrossV3BridgeAdapter_Unit_Concrete_Test is
    AcrossV3BridgeAdapter_Unit_Concrete_Test,
    AuthorizeInBridgeTransfer_Integration_Concrete_Test
{
    function setUp()
        public
        override(AcrossV3BridgeAdapter_Unit_Concrete_Test, AuthorizeInBridgeTransfer_Integration_Concrete_Test)
    {
        AuthorizeInBridgeTransfer_Integration_Concrete_Test.setUp();
        AcrossV3BridgeAdapter_Unit_Concrete_Test.setUp();
    }
}
