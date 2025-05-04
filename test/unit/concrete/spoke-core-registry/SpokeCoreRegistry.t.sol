// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ISpokeCoreRegistry} from "src/interfaces/ISpokeCoreRegistry.sol";
import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";

import {CoreRegistry_Util_Concrete_Test} from "../core-registry/CoreRegistry.t.sol";
import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract SpokeCoreRegistry_Util_Concrete_Test is CoreRegistry_Util_Concrete_Test, Unit_Concrete_Spoke_Test {
    function setUp() public override(CoreRegistry_Util_Concrete_Test, Unit_Concrete_Spoke_Test) {
        Unit_Concrete_Spoke_Test.setUp();
        registry = spokeCoreRegistry;
        coreFactoryAddr = address(spokeCoreFactory);
    }

    function test_SpokeCoreRegistryGetters() public view {
        assertEq(spokeCoreRegistry.caliberBeacon(), address(caliberBeacon));
        assertEq(spokeCoreRegistry.caliberMailboxBeacon(), address(caliberMailboxBeacon));
        assertEq(spokeCoreRegistry.authority(), address(accessManager));
    }

    function test_SetCaliberBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeCoreRegistry.setCaliberBeacon(address(0));
    }

    function test_SetCaliberBeacon() public {
        address newCaliberBeacon = makeAddr("newCaliberBeacon");
        vm.expectEmit(true, true, false, false, address(spokeCoreRegistry));
        emit ICoreRegistry.CaliberBeaconChanged(address(caliberBeacon), newCaliberBeacon);
        vm.prank(dao);
        spokeCoreRegistry.setCaliberBeacon(newCaliberBeacon);
        assertEq(spokeCoreRegistry.caliberBeacon(), newCaliberBeacon);
    }

    function test_SetCaliberMailboxBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeCoreRegistry.setCaliberMailboxBeacon(address(0));
    }

    function test_SetCaliberMailboxBeacon() public {
        address newCaliberMailboxBeacon = makeAddr("newCaliberMailboxBeacon");
        vm.expectEmit(true, true, false, false, address(spokeCoreRegistry));
        emit ISpokeCoreRegistry.CaliberMailboxBeaconChanged(address(caliberMailboxBeacon), newCaliberMailboxBeacon);
        vm.prank(dao);
        spokeCoreRegistry.setCaliberMailboxBeacon(newCaliberMailboxBeacon);
        assertEq(spokeCoreRegistry.caliberMailboxBeacon(), newCaliberMailboxBeacon);
    }
}
