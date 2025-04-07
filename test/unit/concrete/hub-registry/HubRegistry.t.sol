// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IHubRegistry} from "src/interfaces/IHubRegistry.sol";
import {IBaseMakinaRegistry} from "src/interfaces/IBaseMakinaRegistry.sol";

import {BaseMakinaRegistry_Util_Concrete_Test} from "../base-makina-registry/BaseMakinaRegistry.t.sol";
import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

contract HubRegistry_Util_Concrete_Test is BaseMakinaRegistry_Util_Concrete_Test, Unit_Concrete_Hub_Test {
    function setUp() public override(BaseMakinaRegistry_Util_Concrete_Test, Unit_Concrete_Hub_Test) {
        Unit_Concrete_Hub_Test.setUp();
        registry = hubRegistry;
    }

    function test_HubRegistryGetters() public view {
        assertEq(hubRegistry.caliberBeacon(), address(caliberBeacon));
        assertEq(hubRegistry.chainRegistry(), address(chainRegistry));
        assertEq(hubRegistry.machineBeacon(), address(machineBeacon));
        assertEq(hubRegistry.machineFactory(), address(machineFactory));
        assertEq(hubRegistry.authority(), address(accessManager));
    }

    function test_SetCaliberBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setCaliberBeacon(address(0));
    }

    function test_SetCaliberBeacon() public {
        address newCaliberBeacon = makeAddr("newCaliberBeacon");
        vm.expectEmit(false, false, false, false, address(hubRegistry));
        emit IBaseMakinaRegistry.CaliberBeaconChange(address(caliberBeacon), newCaliberBeacon);
        vm.prank(dao);
        hubRegistry.setCaliberBeacon(newCaliberBeacon);
        assertEq(hubRegistry.caliberBeacon(), newCaliberBeacon);
    }

    function test_SetChainRegistry_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setChainRegistry(address(0));
    }

    function test_SetChainRegistry() public {
        address newChainRegistry = makeAddr("newChainRegistry");
        vm.expectEmit(true, true, true, true, address(hubRegistry));
        emit IHubRegistry.ChainRegistryChange(address(chainRegistry), newChainRegistry);
        vm.prank(dao);
        hubRegistry.setChainRegistry(newChainRegistry);
        assertEq(hubRegistry.chainRegistry(), newChainRegistry);
    }

    function test_SetMachineBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setMachineBeacon(address(0));
    }

    function test_SetMachineBeacon() public {
        address newMachineBeacon = makeAddr("newMachineBeacon");
        vm.expectEmit(true, true, true, true, address(hubRegistry));
        emit IHubRegistry.MachineBeaconChange(address(machineBeacon), newMachineBeacon);
        vm.prank(dao);
        hubRegistry.setMachineBeacon(newMachineBeacon);
        assertEq(hubRegistry.machineBeacon(), newMachineBeacon);
    }

    function test_SetMachineFactory_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setMachineFactory(address(0));
    }

    function test_SetMachineFactory() public {
        address newMachineFactory = makeAddr("newMachineFactory");
        vm.expectEmit(true, true, true, true, address(hubRegistry));
        emit IHubRegistry.MachineFactoryChange(address(machineFactory), newMachineFactory);
        vm.prank(dao);
        hubRegistry.setMachineFactory(newMachineFactory);
        assertEq(hubRegistry.machineFactory(), newMachineFactory);
    }
}
