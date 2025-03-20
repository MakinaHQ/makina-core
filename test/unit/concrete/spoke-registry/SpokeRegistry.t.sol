// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ISpokeRegistry} from "src/interfaces/ISpokeRegistry.sol";
import {IBaseMakinaRegistry} from "src/interfaces/IBaseMakinaRegistry.sol";

import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract SpokeRegistry_Util_Concrete_Test is Unit_Concrete_Spoke_Test {
    function test_Getters() public view {
        assertEq(spokeRegistry.oracleRegistry(), address(oracleRegistry));
        assertEq(spokeRegistry.swapModule(), address(swapModule));
        assertEq(spokeRegistry.caliberBeacon(), address(spokeCaliberBeacon));
        assertEq(spokeRegistry.caliberFactory(), address(caliberFactory));
        assertEq(spokeRegistry.spokeCaliberMailboxBeacon(), address(spokeCaliberMailboxBeacon));
        assertEq(spokeRegistry.authority(), address(accessManager));
    }

    function test_SetOracleRegistry_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeRegistry.setOracleRegistry(address(0));
    }

    function test_SetOracleRegistry() public {
        address newOracleRegistry = makeAddr("newOracleRegistry");
        vm.expectEmit(true, true, true, true, address(spokeRegistry));
        emit IBaseMakinaRegistry.OracleRegistryChange(address(oracleRegistry), newOracleRegistry);
        vm.prank(dao);
        spokeRegistry.setOracleRegistry(newOracleRegistry);
        assertEq(spokeRegistry.oracleRegistry(), newOracleRegistry);
    }

    function test_SetSwapModule_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeRegistry.setSwapModule(address(0));
    }

    function test_SetSwapModule() public {
        address newSwapModule = makeAddr("newSwapModule");
        vm.expectEmit(true, true, true, true, address(spokeRegistry));
        emit IBaseMakinaRegistry.SwapModuleChange(address(swapModule), newSwapModule);
        vm.prank(dao);
        spokeRegistry.setSwapModule(newSwapModule);
        assertEq(spokeRegistry.swapModule(), newSwapModule);
    }

    function test_SetCaliberBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeRegistry.setCaliberBeacon(address(0));
    }

    function test_SetCaliberBeacon() public {
        address newCaliberBeacon = makeAddr("newCaliberBeacon");
        vm.expectEmit(false, false, false, false, address(spokeRegistry));
        emit IBaseMakinaRegistry.CaliberBeaconChange(address(spokeCaliberBeacon), newCaliberBeacon);
        vm.prank(dao);
        spokeRegistry.setCaliberBeacon(newCaliberBeacon);
        assertEq(spokeRegistry.caliberBeacon(), newCaliberBeacon);
    }

    function test_SetCaliberFactory_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeRegistry.setCaliberFactory(address(0));
    }

    function test_SetCaliberFactory() public {
        address newCaliberFactory = makeAddr("newCaliberFactory");
        vm.expectEmit(false, false, false, false, address(spokeRegistry));
        emit ISpokeRegistry.CaliberFactoryChange(address(caliberFactory), newCaliberFactory);
        vm.prank(dao);
        spokeRegistry.setCaliberFactory(newCaliberFactory);
        assertEq(spokeRegistry.caliberFactory(), newCaliberFactory);
    }

    function test_SetSpokeCaliberMailboxBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeRegistry.setSpokeCaliberMailboxBeacon(address(0));
    }

    function test_SetSpokeCaliberMailboxBeacon() public {
        address newSpokeCaliberMailboxBeacon = makeAddr("newSpokeCaliberMailboxBeacon");
        vm.expectEmit(false, false, false, false, address(spokeRegistry));
        emit ISpokeRegistry.SpokeCaliberMailboxBeaconChange(
            address(spokeCaliberMailboxBeacon), newSpokeCaliberMailboxBeacon
        );
        vm.prank(dao);
        spokeRegistry.setSpokeCaliberMailboxBeacon(newSpokeCaliberMailboxBeacon);
        assertEq(spokeRegistry.spokeCaliberMailboxBeacon(), newSpokeCaliberMailboxBeacon);
    }
}
