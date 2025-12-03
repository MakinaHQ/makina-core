// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {AcrossV3BridgeConfig} from "src/bridge/configs/AcrossV3BridgeConfig.sol";

import {Base_Test} from "../../../../base/Base.t.sol";

contract AcrossV3BridgeConfig_Unit_Concrete_Test is Base_Test {
    AcrossV3BridgeConfig internal bridgeConfig;

    function setUp() public virtual override {
        Base_Test.setUp();

        accessManager = _deployAccessManager(dao, dao);
        bridgeConfig = _deployAcrossV3BridgeConfig(dao, address(accessManager));
    }

    function test_Getters() public view {
        assertFalse(bridgeConfig.isRouteSupported(address(0), 0, address(0)));
        assertFalse(bridgeConfig.isForeignChainSupported(0));
    }

    function test_SetForeignChainSupported_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        bridgeConfig.setForeignChainSupported(0, false);
    }

    function test_SetForeignChainSupported() public {
        vm.startPrank(address(dao));

        bridgeConfig.setForeignChainSupported(1, true);
        assertTrue(bridgeConfig.isRouteSupported(address(0), 1, address(0)));
        assertTrue(bridgeConfig.isRouteSupported(address(2), 1, address(3)));
        assertTrue(bridgeConfig.isForeignChainSupported(1));

        bridgeConfig.setForeignChainSupported(1, true);
        assertTrue(bridgeConfig.isRouteSupported(address(0), 1, address(0)));
        assertTrue(bridgeConfig.isRouteSupported(address(2), 1, address(3)));
        assertTrue(bridgeConfig.isForeignChainSupported(1));

        bridgeConfig.setForeignChainSupported(1, false);
        assertFalse(bridgeConfig.isRouteSupported(address(0), 1, address(0)));
        assertFalse(bridgeConfig.isRouteSupported(address(2), 1, address(3)));
        assertFalse(bridgeConfig.isForeignChainSupported(1));

        bridgeConfig.setForeignChainSupported(1, false);
        assertFalse(bridgeConfig.isRouteSupported(address(0), 1, address(0)));
        assertFalse(bridgeConfig.isRouteSupported(address(2), 1, address(3)));
        assertFalse(bridgeConfig.isForeignChainSupported(1));
    }
}
