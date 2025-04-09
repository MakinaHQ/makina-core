// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

import {AuthorizeInBridgeTransfer_Integration_Concrete_Test} from
    "../bridge-adapter/authorize-in-bridge-transfer/AuthorizeInBridgeTransfer.t.sol";
import {BridgeAdapter_Unit_Concrete_Test} from "../bridge-adapter/BridgeAdapter.t.sol";

abstract contract AcrossV3BridgeAdapter_Unit_Concrete_Test is BridgeAdapter_Unit_Concrete_Test {
    function setUp() public virtual override {
        BridgeAdapter_Unit_Concrete_Test.setUp();

        address acrossV3SpokePool = makeAddr("acrossV3SpokePool");

        address beacon = address(_deployAccrossV3BridgeAdapterBeacon(dao, address(acrossV3SpokePool)));
        bridgeAdapter = IBridgeAdapter(
            address(new BeaconProxy(beacon, abi.encodeCall(IBridgeAdapter.initialize, (address(parent), ""))))
        );
    }
}

contract Getters_AcrossV3BridgeAdapter_Unit_Concrete_Test is AcrossV3BridgeAdapter_Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(bridgeAdapter.parent(), address(parent));
        assertEq(bridgeAdapter.bridgeId(), uint256(IBridgeAdapter.Bridge.ACROSS_V3));
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
