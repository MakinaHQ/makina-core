// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ISpokeRegistry} from "src/interfaces/ISpokeRegistry.sol";
import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";

import {CoreRegistry_Util_Concrete_Test} from "../core-registry/CoreRegistry.t.sol";
import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract SpokeRegistry_Util_Concrete_Test is CoreRegistry_Util_Concrete_Test, Unit_Concrete_Spoke_Test {
    function setUp() public override(CoreRegistry_Util_Concrete_Test, Unit_Concrete_Spoke_Test) {
        Unit_Concrete_Spoke_Test.setUp();
        registry = spokeRegistry;
        coreFactoryAddr = address(caliberFactory);
    }

    function test_SpokeRegistryGetters() public view {
        assertEq(spokeRegistry.caliberBeacon(), address(caliberBeacon));
        assertEq(spokeRegistry.caliberMailboxBeacon(), address(caliberMailboxBeacon));
        assertEq(spokeRegistry.authority(), address(accessManager));
    }

    function test_SetCaliberBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeRegistry.setCaliberBeacon(address(0));
    }

    function test_SetCaliberBeacon() public {
        address newCaliberBeacon = makeAddr("newCaliberBeacon");
        vm.expectEmit(true, true, false, false, address(spokeRegistry));
        emit ICoreRegistry.CaliberBeaconChange(address(caliberBeacon), newCaliberBeacon);
        vm.prank(dao);
        spokeRegistry.setCaliberBeacon(newCaliberBeacon);
        assertEq(spokeRegistry.caliberBeacon(), newCaliberBeacon);
    }

    function test_SetCaliberMailboxBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeRegistry.setCaliberMailboxBeacon(address(0));
    }

    function test_SetCaliberMailboxBeacon() public {
        address newCaliberMailboxBeacon = makeAddr("newCaliberMailboxBeacon");
        vm.expectEmit(true, true, false, false, address(spokeRegistry));
        emit ISpokeRegistry.CaliberMailboxBeaconChange(address(caliberMailboxBeacon), newCaliberMailboxBeacon);
        vm.prank(dao);
        spokeRegistry.setCaliberMailboxBeacon(newCaliberMailboxBeacon);
        assertEq(spokeRegistry.caliberMailboxBeacon(), newCaliberMailboxBeacon);
    }
}
