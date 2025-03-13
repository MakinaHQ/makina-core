// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IHubRegistry} from "src/interfaces/IHubRegistry.sol";
import {IBaseMakinaRegistry} from "src/interfaces/IBaseMakinaRegistry.sol";

import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

contract HubRegistry_Util_Concrete_Test is Unit_Concrete_Hub_Test {
    function test_Getters() public view {
        assertEq(hubRegistry.chainRegistry(), address(chainRegistry));
        assertEq(hubRegistry.oracleRegistry(), address(oracleRegistry));
        assertEq(hubRegistry.swapper(), address(swapper));
        assertEq(hubRegistry.machineBeacon(), address(machineBeacon));
        assertEq(hubRegistry.machineFactory(), address(machineFactory));
        assertEq(hubRegistry.caliberBeacon(), address(hubCaliberBeacon));
        assertEq(hubRegistry.hubDualMailboxBeacon(), address(hubDualMailboxBeacon));
        assertEq(hubRegistry.authority(), address(accessManager));
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

    function test_SetOracleRegistry_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setOracleRegistry(address(0));
    }

    function test_SetOracleRegistry() public {
        address newOracleRegistry = makeAddr("newOracleRegistry");
        vm.expectEmit(true, true, true, true, address(hubRegistry));
        emit IBaseMakinaRegistry.OracleRegistryChange(address(oracleRegistry), newOracleRegistry);
        vm.prank(dao);
        hubRegistry.setOracleRegistry(newOracleRegistry);
        assertEq(hubRegistry.oracleRegistry(), newOracleRegistry);
    }

    function test_SetSwapper_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setSwapper(address(0));
    }

    function test_SetSwapper() public {
        address newSwapper = makeAddr("newSwapper");
        vm.expectEmit(true, true, true, true, address(hubRegistry));
        emit IBaseMakinaRegistry.SwapperChange(address(swapper), newSwapper);
        vm.prank(dao);
        hubRegistry.setSwapper(newSwapper);
        assertEq(hubRegistry.swapper(), newSwapper);
    }

    function test_SetCaliberBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setCaliberBeacon(address(0));
    }

    function test_SetCaliberBeacon() public {
        address newCaliberBeacon = makeAddr("newCaliberBeacon");
        vm.expectEmit(false, false, false, false, address(hubRegistry));
        emit IBaseMakinaRegistry.CaliberBeaconChange(address(hubCaliberBeacon), newCaliberBeacon);
        vm.prank(dao);
        hubRegistry.setCaliberBeacon(newCaliberBeacon);
        assertEq(hubRegistry.caliberBeacon(), newCaliberBeacon);
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

    function test_SetHubDualMailboxBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setHubDualMailboxBeacon(address(0));
    }

    function test_SetHubDualMailboxBeacon() public {
        address newHubDualMailboxBeacon = makeAddr("newHubDualMailboxBeacon");
        vm.expectEmit(false, false, false, false, address(hubRegistry));
        emit IHubRegistry.HubDualMailboxBeaconChange(address(hubDualMailboxBeacon), newHubDualMailboxBeacon);
        vm.prank(dao);
        hubRegistry.setHubDualMailboxBeacon(newHubDualMailboxBeacon);
        assertEq(hubRegistry.hubDualMailboxBeacon(), newHubDualMailboxBeacon);
    }

    function test_SetSpokeMachineMailboxBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setSpokeMachineMailboxBeacon(address(0));
    }

    function test_SetSpokeMachineMailboxBeacon() public {
        address newSpokeMachineMailboxBeacon = makeAddr("newSpokeMachineMailboxBeacon");
        vm.expectEmit(false, false, false, false, address(hubRegistry));
        emit IHubRegistry.SpokeMachineMailboxBeaconChange(
            address(spokeMachineMailboxBeacon), newSpokeMachineMailboxBeacon
        );
        vm.prank(dao);
        hubRegistry.setSpokeMachineMailboxBeacon(newSpokeMachineMailboxBeacon);
        assertEq(hubRegistry.spokeMachineMailboxBeacon(), newSpokeMachineMailboxBeacon);
    }
}
