// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IHubCoreRegistry} from "src/interfaces/IHubCoreRegistry.sol";
import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";

import {CoreRegistry_Util_Concrete_Test} from "../core-registry/CoreRegistry.t.sol";
import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

contract HubCoreRegistry_Util_Concrete_Test is CoreRegistry_Util_Concrete_Test, Unit_Concrete_Hub_Test {
    function setUp() public override(CoreRegistry_Util_Concrete_Test, Unit_Concrete_Hub_Test) {
        Unit_Concrete_Hub_Test.setUp();
        registry = hubCoreRegistry;
        coreFactoryAddr = address(machineFactory);
    }

    function test_HubCoreRegistryGetters() public view {
        assertEq(hubCoreRegistry.caliberBeacon(), address(caliberBeacon));
        assertEq(hubCoreRegistry.chainRegistry(), address(chainRegistry));
        assertEq(hubCoreRegistry.machineBeacon(), address(machineBeacon));
        assertEq(hubCoreRegistry.authority(), address(accessManager));
    }

    function test_SetCaliberBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubCoreRegistry.setCaliberBeacon(address(0));
    }

    function test_SetCaliberBeacon() public {
        address newCaliberBeacon = makeAddr("newCaliberBeacon");
        vm.expectEmit(true, true, false, false, address(hubCoreRegistry));
        emit ICoreRegistry.CaliberBeaconChange(address(caliberBeacon), newCaliberBeacon);
        vm.prank(dao);
        hubCoreRegistry.setCaliberBeacon(newCaliberBeacon);
        assertEq(hubCoreRegistry.caliberBeacon(), newCaliberBeacon);
    }

    function test_SetChainRegistry_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubCoreRegistry.setChainRegistry(address(0));
    }

    function test_SetChainRegistry() public {
        address newChainRegistry = makeAddr("newChainRegistry");
        vm.expectEmit(true, true, false, false, address(hubCoreRegistry));
        emit IHubCoreRegistry.ChainRegistryChange(address(chainRegistry), newChainRegistry);
        vm.prank(dao);
        hubCoreRegistry.setChainRegistry(newChainRegistry);
        assertEq(hubCoreRegistry.chainRegistry(), newChainRegistry);
    }

    function test_SetMachineBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubCoreRegistry.setMachineBeacon(address(0));
    }

    function test_SetMachineBeacon() public {
        address newMachineBeacon = makeAddr("newMachineBeacon");
        vm.expectEmit(true, true, false, false, address(hubCoreRegistry));
        emit IHubCoreRegistry.MachineBeaconChange(address(machineBeacon), newMachineBeacon);
        vm.prank(dao);
        hubCoreRegistry.setMachineBeacon(newMachineBeacon);
        assertEq(hubCoreRegistry.machineBeacon(), newMachineBeacon);
    }

    function test_SetPreDepositVaultBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubCoreRegistry.setPreDepositVaultBeacon(address(0));
    }

    function test_SetPreDepositVaultBeacon() public {
        address newPreDepositVaultBeacon = makeAddr("newPreDepositVaultBeacon");
        vm.expectEmit(true, true, false, false, address(hubCoreRegistry));
        emit IHubCoreRegistry.PreDepositVaultBeaconChange(address(preDepositVaultBeacon), newPreDepositVaultBeacon);
        vm.prank(dao);
        hubCoreRegistry.setPreDepositVaultBeacon(newPreDepositVaultBeacon);
        assertEq(hubCoreRegistry.preDepositVaultBeacon(), newPreDepositVaultBeacon);
    }
}
