// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBaseMakinaRegistry} from "src/interfaces/IBaseMakinaRegistry.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";

import {BridgeController_Integration_Concrete_Test} from "../bridge-controller/BridgeController.t.sol";
import {CreateBridgeAdapter_Integration_Concrete_Test} from
    "../bridge-controller/create-bridge-adapter/createBridgeAdapter.t.sol";
import {GetBridgeAdapter_Integration_Concrete_Test} from
    "../bridge-controller/get-bridge-adapter/getBridgeAdapter.t.sol";
import {IsBridgeSupported_Integration_Concrete_Test} from
    "../bridge-controller/is-bridge-supported/isBridgeSupported.t.sol";
import {Integration_Concrete_Spoke_Test} from "../IntegrationConcrete.t.sol";

abstract contract CaliberMailbox_Integration_Concrete_Test is Integration_Concrete_Spoke_Test {
    address public spokeAccountingTokenAddr;
    address public spokeBridgeAdapterAddr;

    function setUp() public virtual override {
        Integration_Concrete_Spoke_Test.setUp();

        vm.startPrank(address(dao));
        spokeRegistry.setBridgeAdapterBeacon(
            IBridgeAdapter.Bridge.ACROSS_V3,
            address(_deployAccrossV3BridgeAdapterBeacon(dao, address(acrossV3SpokePool)))
        );
        vm.stopPrank();
    }
}

abstract contract BridgeController_CaliberMailbox_Integration_Concrete_Test is
    CaliberMailbox_Integration_Concrete_Test,
    BridgeController_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(CaliberMailbox_Integration_Concrete_Test, BridgeController_Integration_Concrete_Test)
    {
        CaliberMailbox_Integration_Concrete_Test.setUp();

        registry = IBaseMakinaRegistry(address(spokeRegistry));
        bridgeController = IBridgeController(address(caliberMailbox));
    }
}

contract CreateBridgeAdapter_CaliberMailbox_Integration_Concrete_Test is
    BridgeController_CaliberMailbox_Integration_Concrete_Test,
    CreateBridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_CaliberMailbox_Integration_Concrete_Test, CreateBridgeAdapter_Integration_Concrete_Test)
    {
        BridgeController_CaliberMailbox_Integration_Concrete_Test.setUp();
    }
}

contract GetBridgeAdapter_CaliberMailbox_Integration_Concrete_Test is
    BridgeController_CaliberMailbox_Integration_Concrete_Test,
    GetBridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_CaliberMailbox_Integration_Concrete_Test, GetBridgeAdapter_Integration_Concrete_Test)
    {
        BridgeController_CaliberMailbox_Integration_Concrete_Test.setUp();
    }
}

contract IsBridgeSupported_CaliberMailbox_Integration_Concrete_Test is
    BridgeController_CaliberMailbox_Integration_Concrete_Test,
    IsBridgeSupported_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_CaliberMailbox_Integration_Concrete_Test, IsBridgeSupported_Integration_Concrete_Test)
    {
        BridgeController_CaliberMailbox_Integration_Concrete_Test.setUp();
    }
}
