// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ISpokeRegistry} from "src/interfaces/ISpokeRegistry.sol";
import {IBaseMakinaRegistry} from "src/interfaces/IBaseMakinaRegistry.sol";

import {BaseMakinaRegistry_Util_Concrete_Test} from "../base-makina-registry/BaseMakinaRegistry.t.sol";
import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract SpokeRegistry_Util_Concrete_Test is BaseMakinaRegistry_Util_Concrete_Test, Unit_Concrete_Spoke_Test {
    function setUp() public override(BaseMakinaRegistry_Util_Concrete_Test, Unit_Concrete_Spoke_Test) {
        Unit_Concrete_Spoke_Test.setUp();
        registry = spokeRegistry;
    }

    function test_SpokeRegistryGetters() public view {
        assertEq(spokeRegistry.caliberBeacon(), address(caliberBeacon));
        assertEq(spokeRegistry.caliberFactory(), address(caliberFactory));
        assertEq(spokeRegistry.caliberMailboxBeacon(), address(caliberMailboxBeacon));
        assertEq(spokeRegistry.authority(), address(accessManager));
    }

    function test_SetCaliberBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeRegistry.setCaliberBeacon(address(0));
    }

    function test_SetCaliberBeacon() public {
        address newCaliberBeacon = makeAddr("newCaliberBeacon");
        vm.expectEmit(false, false, false, false, address(spokeRegistry));
        emit IBaseMakinaRegistry.CaliberBeaconChange(address(caliberBeacon), newCaliberBeacon);
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

    function test_SetCaliberMailboxBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeRegistry.setCaliberMailboxBeacon(address(0));
    }

    function test_SetCaliberMailboxBeacon() public {
        address newCaliberMailboxBeacon = makeAddr("newCaliberMailboxBeacon");
        vm.expectEmit(false, false, false, false, address(spokeRegistry));
        emit ISpokeRegistry.CaliberMailboxBeaconChange(address(caliberMailboxBeacon), newCaliberMailboxBeacon);
        vm.prank(dao);
        spokeRegistry.setCaliberMailboxBeacon(newCaliberMailboxBeacon);
        assertEq(spokeRegistry.caliberMailboxBeacon(), newCaliberMailboxBeacon);
    }
}
