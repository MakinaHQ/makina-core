// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./BaseTest.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IHubRegistry} from "../src/interfaces/IHubRegistry.sol";
import {IBaseMakinaRegistry} from "../src/interfaces/IBaseMakinaRegistry.sol";

contract HubRegistryTest is BaseTest {
    address machineFactoryAddr;
    address machineBeaconAddr;
    address machineHubInboxBeaconAddr;

    function _setUp() public override {
        machineFactoryAddr = makeAddr("machineFactory");
        machineBeaconAddr = makeAddr("machineBeacon");
        machineHubInboxBeaconAddr = makeAddr("machineHubInboxBeacon");
    }

    function test_hubRegistry_getters() public view {
        assertEq(hubRegistry.oracleRegistry(), address(oracleRegistry));
        assertEq(hubRegistry.swapper(), address(swapper));
        assertEq(hubRegistry.machineBeacon(), machineBeaconAddr);
        assertEq(hubRegistry.machineHubInboxBeacon(), machineHubInboxBeaconAddr);
        assertEq(hubRegistry.machineFactory(), machineFactoryAddr);
        assertEq(hubRegistry.caliberBeacon(), address(caliberBeacon));
        assertEq(hubRegistry.caliberInboxBeacon(), address(caliberInboxBeacon));
        assertEq(hubRegistry.caliberFactory(), address(caliberFactory));
        assertEq(hubRegistry.authority(), address(accessManager));
    }

    function test_cannotSetOracleRegistryWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setOracleRegistry(address(0));
    }

    function test_setOracleRegistry() public {
        address newOracleRegistry = makeAddr("newOracleRegistry");
        vm.expectEmit(true, true, true, true, address(hubRegistry));
        emit IBaseMakinaRegistry.OracleRegistryChange(address(oracleRegistry), newOracleRegistry);
        vm.prank(dao);
        hubRegistry.setOracleRegistry(newOracleRegistry);
        assertEq(hubRegistry.oracleRegistry(), newOracleRegistry);
    }

    function test_cannotSetSwapperWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setSwapper(address(0));
    }

    function test_setSwapper() public {
        address newSwapper = makeAddr("newSwapper");
        vm.expectEmit(true, true, true, true, address(hubRegistry));
        emit IBaseMakinaRegistry.SwapperChange(address(swapper), newSwapper);
        vm.prank(dao);
        hubRegistry.setSwapper(newSwapper);
        assertEq(hubRegistry.swapper(), newSwapper);
    }

    function test_cannotSetCaliberBeaconWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setCaliberBeacon(address(0));
    }

    function test_setCaliberBeacon() public {
        address newCaliberBeacon = makeAddr("newCaliberBeacon");
        vm.expectEmit(false, false, false, false, address(hubRegistry));
        emit IBaseMakinaRegistry.CaliberBeaconChange(address(caliberBeacon), newCaliberBeacon);
        vm.prank(dao);
        hubRegistry.setCaliberBeacon(newCaliberBeacon);
        assertEq(hubRegistry.caliberBeacon(), newCaliberBeacon);
    }

    function test_cannotSetCaliberInboxBeaconWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setCaliberInboxBeacon(address(0));
    }

    function test_setCaliberInboxBeacon() public {
        address newCaliberInboxBeacon = makeAddr("newCaliberInboxBeacon");
        vm.expectEmit(false, false, false, false, address(hubRegistry));
        emit IBaseMakinaRegistry.CaliberInboxBeaconChange(address(caliberInboxBeacon), newCaliberInboxBeacon);
        vm.prank(dao);
        hubRegistry.setCaliberInboxBeacon(newCaliberInboxBeacon);
        assertEq(hubRegistry.caliberInboxBeacon(), newCaliberInboxBeacon);
    }

    function test_cannotSetCaliberFactoryWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setCaliberFactory(address(0));
    }

    function test_setCaliberFactory() public {
        address newCaliberFactory = makeAddr("newCaliberFactory");
        vm.expectEmit(false, false, false, false, address(hubRegistry));
        emit IBaseMakinaRegistry.CaliberFactoryChange(address(caliberFactory), newCaliberFactory);
        vm.prank(dao);
        hubRegistry.setCaliberFactory(newCaliberFactory);
        assertEq(hubRegistry.caliberFactory(), newCaliberFactory);
    }

    function test_cannotSetMachineBeaconWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setMachineBeacon(address(0));
    }

    function test_setMachineBeacon() public {
        address newMachineBeacon = makeAddr("newMachineBeacon");
        vm.expectEmit(true, true, true, true, address(hubRegistry));
        emit IHubRegistry.MachineBeaconChange(machineBeaconAddr, newMachineBeacon);
        vm.prank(dao);
        hubRegistry.setMachineBeacon(newMachineBeacon);
        assertEq(hubRegistry.machineBeacon(), newMachineBeacon);
    }

    function test_cannotSetMachineHubInboxBeaconWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setMachineHubInboxBeacon(address(0));
    }

    function test_setMachineHubInboxBeacon() public {
        address newMachineHubInboxBeacon = makeAddr("newMachineHubInboxBeacon");
        vm.expectEmit(true, true, true, true, address(hubRegistry));
        emit IHubRegistry.MachineHubInboxBeaconChange(machineHubInboxBeaconAddr, newMachineHubInboxBeacon);
        vm.prank(dao);
        hubRegistry.setMachineHubInboxBeacon(newMachineHubInboxBeacon);
        assertEq(hubRegistry.machineHubInboxBeacon(), newMachineHubInboxBeacon);
    }

    function test_cannotSetMachineFactoryWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubRegistry.setMachineFactory(address(0));
    }

    function test_setMachineFactory() public {
        address newMachineFactory = makeAddr("newMachineFactory");
        vm.expectEmit(true, true, true, true, address(hubRegistry));
        emit IHubRegistry.MachineFactoryChange(machineFactoryAddr, newMachineFactory);
        vm.prank(dao);
        hubRegistry.setMachineFactory(newMachineFactory);
        assertEq(hubRegistry.machineFactory(), newMachineFactory);
    }
}
