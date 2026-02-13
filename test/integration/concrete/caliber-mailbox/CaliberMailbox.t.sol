// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AcrossV3BridgeConfig} from "src/bridge/configs/AcrossV3BridgeConfig.sol";
import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";
import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";

import {BridgeController_Integration_Concrete_Test} from "../bridge-controller/BridgeController.t.sol";
import {CreateBridgeAdapter_Integration_Concrete_Test} from
    "../bridge-controller/create-bridge-adapter/createBridgeAdapter.t.sol";
import {GetBridgeAdapter_Integration_Concrete_Test} from
    "../bridge-controller/get-bridge-adapter/getBridgeAdapter.t.sol";
import {GetMaxBridgeLossBps_Integration_Concrete_Test} from
    "../bridge-controller/get-max-bridge-loss-bps/getMaxBridgeLossBps.t.sol";
import {IsBridgeSupported_Integration_Concrete_Test} from
    "../bridge-controller/is-bridge-supported/isBridgeSupported.t.sol";
import {IsOutTransferEnabled_Integration_Concrete_Test} from
    "../bridge-controller/is-out-transfer-enabled/isOutTransferEnabled.t.sol";
import {SetMaxBridgeLossBps_Integration_Concrete_Test} from
    "../bridge-controller/set-max-bridge-loss-bps/setMaxBridgeLossBps.t.sol";
import {SetOutTransferEnabled_Integration_Concrete_Test} from
    "../bridge-controller/set-out-transfer-enabled/setOutTransferEnabled.t.sol";
import {Integration_Concrete_Spoke_Test} from "../IntegrationConcrete.t.sol";

abstract contract CaliberMailbox_Integration_Concrete_Test is Integration_Concrete_Spoke_Test {
    address public hubAccountingTokenAddr;
    address public hubBridgeAdapterAddr;

    function setUp() public virtual override {
        Integration_Concrete_Spoke_Test.setUp();

        vm.startPrank(address(dao));
        spokeCoreRegistry.setBridgeAdapterBeacon(
            ACROSS_V3_BRIDGE_ID,
            address(
                _deployAcrossV3BridgeAdapterBeacon(
                    address(accessManager), address(spokeCoreRegistry), address(acrossV3SpokePool)
                )
            )
        );
        AcrossV3BridgeConfig config = _deployAcrossV3BridgeConfig(address(accessManager), address(accessManager));
        spokeCoreRegistry.setBridgeConfig(ACROSS_V3_BRIDGE_ID, address(config));
        config.setForeignChainSupported(hubChainId, true);
        vm.stopPrank();

        hubAccountingTokenAddr = makeAddr("hubAccountingToken");
        hubBridgeAdapterAddr = makeAddr("hubBridgeAdapter");
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

        registry = ICoreRegistry(address(spokeCoreRegistry));
        bridgeController = IBridgeController(address(caliberMailbox));
        bridgeAdapterFactory = IBridgeAdapterFactory(address(spokeCoreFactory));
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

contract IsOutTransferEnabled_CaliberMailbox_Integration_Concrete_Test is
    BridgeController_CaliberMailbox_Integration_Concrete_Test,
    IsOutTransferEnabled_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_CaliberMailbox_Integration_Concrete_Test, IsOutTransferEnabled_Integration_Concrete_Test)
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

contract GetMaxBridgeLossBps_CaliberMailbox_Integration_Concrete_Test is
    BridgeController_CaliberMailbox_Integration_Concrete_Test,
    GetMaxBridgeLossBps_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_CaliberMailbox_Integration_Concrete_Test, GetMaxBridgeLossBps_Integration_Concrete_Test)
    {
        BridgeController_CaliberMailbox_Integration_Concrete_Test.setUp();
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

contract SetMaxBridgeLossBps_CaliberMailbox_Integration_Concrete_Test is
    BridgeController_CaliberMailbox_Integration_Concrete_Test,
    SetMaxBridgeLossBps_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_CaliberMailbox_Integration_Concrete_Test, SetMaxBridgeLossBps_Integration_Concrete_Test)
    {
        BridgeController_CaliberMailbox_Integration_Concrete_Test.setUp();
    }
}

contract SetOutTransferEnabled_CaliberMailbox_Integration_Concrete_Test is
    BridgeController_CaliberMailbox_Integration_Concrete_Test,
    SetOutTransferEnabled_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_CaliberMailbox_Integration_Concrete_Test, SetOutTransferEnabled_Integration_Concrete_Test)
    {
        BridgeController_CaliberMailbox_Integration_Concrete_Test.setUp();
    }
}
