// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IBaseMakinaRegistry} from "src/interfaces/IBaseMakinaRegistry.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

abstract contract BaseMakinaRegistry_Util_Concrete_Test is Unit_Concrete_Test {
    IBaseMakinaRegistry internal registry;

    address internal coreFactoryAddr;

    function setUp() public virtual override {}

    function test_BaseMakinaRegistryGetters() public view {
        assertEq(registry.coreFactory(), coreFactoryAddr);
        assertEq(registry.oracleRegistry(), address(oracleRegistry));
        assertEq(registry.tokenRegistry(), address(tokenRegistry));
        assertEq(registry.swapModule(), address(swapModule));
    }

    function test_SetCoreFactory_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        registry.setCoreFactory(address(0));
    }

    function test_SetCoreFactory() public {
        address newCoreFactory = makeAddr("newCoreFactory");
        vm.expectEmit(true, true, true, true, address(registry));
        emit IBaseMakinaRegistry.CoreFactoryChange(coreFactoryAddr, newCoreFactory);
        vm.prank(dao);
        registry.setCoreFactory(newCoreFactory);
        assertEq(registry.coreFactory(), newCoreFactory);
    }

    function test_SetOracleRegistry_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        registry.setOracleRegistry(address(0));
    }

    function test_SetOracleRegistry() public {
        address newOracleRegistry = makeAddr("newOracleRegistry");
        vm.expectEmit(true, true, true, true, address(registry));
        emit IBaseMakinaRegistry.OracleRegistryChange(address(oracleRegistry), newOracleRegistry);
        vm.prank(dao);
        registry.setOracleRegistry(newOracleRegistry);
        assertEq(registry.oracleRegistry(), newOracleRegistry);
    }

    function test_SetTokenRegistry_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        registry.setTokenRegistry(address(0));
    }

    function test_SetTokenRegistry() public {
        address newTokenRegistry = makeAddr("newTokenRegistry");
        vm.expectEmit(true, true, true, true, address(registry));
        emit IBaseMakinaRegistry.TokenRegistryChange(address(tokenRegistry), newTokenRegistry);
        vm.prank(dao);
        registry.setTokenRegistry(newTokenRegistry);
        assertEq(registry.tokenRegistry(), newTokenRegistry);
    }

    function test_SetSwapModule_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        registry.setSwapModule(address(0));
    }

    function test_SetSwapModule() public {
        address newSwapModule = makeAddr("newSwapModule");
        vm.expectEmit(true, true, true, true, address(registry));
        emit IBaseMakinaRegistry.SwapModuleChange(address(swapModule), newSwapModule);
        vm.prank(dao);
        registry.setSwapModule(newSwapModule);
        assertEq(registry.swapModule(), newSwapModule);
    }

    function test_SetBridgeAdapterBeacon_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        registry.setBridgeAdapterBeacon(IBridgeAdapter.Bridge.ACROSS_V3, address(0));
    }

    function test_SetBridgeAdapterBeacon() public {
        address newBridgeAdapterBeacon = makeAddr("newBridgeAdapterBeacon");
        vm.expectEmit(false, true, false, false, address(registry));
        emit IBaseMakinaRegistry.BridgeAdapterBeaconChange(
            uint256(IBridgeAdapter.Bridge.ACROSS_V3), address(0), newBridgeAdapterBeacon
        );
        vm.prank(dao);
        registry.setBridgeAdapterBeacon(IBridgeAdapter.Bridge.ACROSS_V3, newBridgeAdapterBeacon);
        assertEq(registry.bridgeAdapterBeacon(IBridgeAdapter.Bridge.ACROSS_V3), newBridgeAdapterBeacon);
    }
}
