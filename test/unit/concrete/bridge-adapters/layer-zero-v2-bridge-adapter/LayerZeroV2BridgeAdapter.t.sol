// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IMakinaContext} from "src/interfaces/IMakinaContext.sol";

import {
    AuthorizeInBridgeTransfer_Integration_Concrete_Test
} from "../bridge-adapter/authorize-in-bridge-transfer/authorizeInBridgeTransfer.t.sol";
import {BridgeAdapter_Unit_Concrete_Test} from "../bridge-adapter/BridgeAdapter.t.sol";

abstract contract LayerZeroV2BridgeAdapter_Unit_Concrete_Test is BridgeAdapter_Unit_Concrete_Test {
    address internal layerZeroV2Endpoint;

    function setUp() public virtual override {
        BridgeAdapter_Unit_Concrete_Test.setUp();

        layerZeroV2Endpoint = makeAddr("layerZeroV2Endpoint");

        address beacon = address(_deployLayerZeroV2BridgeAdapterBeacon(dao, address(coreRegistry), layerZeroV2Endpoint));
        bridgeAdapter = IBridgeAdapter(
            address(new BeaconProxy(beacon, abi.encodeCall(IBridgeAdapter.initialize, (address(controller), ""))))
        );
    }
}

contract Getters_LayerZeroV2BridgeAdapter_Unit_Concrete_Test is LayerZeroV2BridgeAdapter_Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(IMakinaContext(address(bridgeAdapter)).registry(), address(coreRegistry));
        assertEq(bridgeAdapter.controller(), address(controller));
        assertEq(bridgeAdapter.bridgeId(), LAYER_ZERO_V2_BRIDGE_ID);
        assertEq(bridgeAdapter.approvalTarget(), address(0));
        assertEq(bridgeAdapter.executionTarget(), address(0));
        assertEq(bridgeAdapter.receiveSource(), layerZeroV2Endpoint);
        assertEq(bridgeAdapter.nextOutTransferId(), 1);
        assertEq(bridgeAdapter.nextInTransferId(), 1);
    }
}

contract AuthorizeInBridgeTransfer_LayerZeroV2BridgeAdapter_Unit_Concrete_Test is
    LayerZeroV2BridgeAdapter_Unit_Concrete_Test,
    AuthorizeInBridgeTransfer_Integration_Concrete_Test
{
    function setUp()
        public
        override(LayerZeroV2BridgeAdapter_Unit_Concrete_Test, AuthorizeInBridgeTransfer_Integration_Concrete_Test)
    {
        AuthorizeInBridgeTransfer_Integration_Concrete_Test.setUp();
        LayerZeroV2BridgeAdapter_Unit_Concrete_Test.setUp();
    }
}
