// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {AcrossV3BridgeConfig} from "src/bridge/configs/AcrossV3BridgeConfig.sol";

import {Base_Test} from "../../../../base/Base.t.sol";

contract AcrossV3BridgeConfig_Unit_Concrete_Test is Base_Test {
    AcrossV3BridgeConfig internal acrossV3BridgeConfig;

    function setUp() public virtual override {
        Base_Test.setUp();

        accessManager = _deployAccessManager(deployer, deployer);
        acrossV3BridgeConfig = _deployAcrossV3BridgeConfig(address(accessManager), address(accessManager));

        _setupAcrossV3BridgeConfigAMFunctionRoles(address(accessManager), address(acrossV3BridgeConfig), vm);
        setupAccessManagerRolesAndOwnership();
    }

    function test_Getters() public view {
        assertFalse(acrossV3BridgeConfig.isRouteSupported(address(0), 0, address(0)));
        assertFalse(acrossV3BridgeConfig.isForeignChainSupported(0));
    }

    function test_SetForeignChainSupported_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        acrossV3BridgeConfig.setForeignChainSupported(0, false);
    }

    function test_SetForeignChainSupported() public {
        vm.startPrank(address(dao));

        acrossV3BridgeConfig.setForeignChainSupported(1, true);
        assertTrue(acrossV3BridgeConfig.isRouteSupported(address(0), 1, address(0)));
        assertTrue(acrossV3BridgeConfig.isRouteSupported(address(2), 1, address(3)));
        assertTrue(acrossV3BridgeConfig.isForeignChainSupported(1));

        acrossV3BridgeConfig.setForeignChainSupported(1, true);
        assertTrue(acrossV3BridgeConfig.isRouteSupported(address(0), 1, address(0)));
        assertTrue(acrossV3BridgeConfig.isRouteSupported(address(2), 1, address(3)));
        assertTrue(acrossV3BridgeConfig.isForeignChainSupported(1));

        acrossV3BridgeConfig.setForeignChainSupported(1, false);
        assertFalse(acrossV3BridgeConfig.isRouteSupported(address(0), 1, address(0)));
        assertFalse(acrossV3BridgeConfig.isRouteSupported(address(2), 1, address(3)));
        assertFalse(acrossV3BridgeConfig.isForeignChainSupported(1));

        acrossV3BridgeConfig.setForeignChainSupported(1, false);
        assertFalse(acrossV3BridgeConfig.isRouteSupported(address(0), 1, address(0)));
        assertFalse(acrossV3BridgeConfig.isRouteSupported(address(2), 1, address(3)));
        assertFalse(acrossV3BridgeConfig.isForeignChainSupported(1));
    }
}
