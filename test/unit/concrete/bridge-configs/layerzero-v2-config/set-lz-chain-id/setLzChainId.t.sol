// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ILayerZeroV2BridgeConfig} from "src/interfaces/ILayerZeroV2BridgeConfig.sol";
import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeConfig_Unit_Concrete_Test} from "../LayerZeroV2BridgeConfig.t.sol";

contract SetLzChainId_Unit_Concrete_Test is LayerZeroV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        layerZeroV2BridgeConfig.setLzChainId(0, 0);
    }

    function test_RevertWhen_ZeroChainId() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        layerZeroV2BridgeConfig.setLzChainId(0, 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        layerZeroV2BridgeConfig.setLzChainId(1, 0);
    }

    function test_SetLzChainId_DifferentIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.LzChainIdRegistered(1, 2);
        layerZeroV2BridgeConfig.setLzChainId(1, 2);

        assertEq(layerZeroV2BridgeConfig.evmToLzChainId(1), 2);
        assertEq(layerZeroV2BridgeConfig.lzToEvmChainId(2), 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 2));
        layerZeroV2BridgeConfig.evmToLzChainId(2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzChainIdNotRegistered.selector, 1));
        layerZeroV2BridgeConfig.lzToEvmChainId(1);
    }

    function test_SetLzChainId_SameIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.LzChainIdRegistered(2, 2);
        layerZeroV2BridgeConfig.setLzChainId(2, 2);

        assertEq(layerZeroV2BridgeConfig.evmToLzChainId(2), 2);
        assertEq(layerZeroV2BridgeConfig.lzToEvmChainId(2), 2);
    }

    function test_SetLzChainId_ReassignLzChainId() public {
        vm.startPrank(dao);

        layerZeroV2BridgeConfig.setLzChainId(1, 1);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.LzChainIdRegistered(1, 2);
        layerZeroV2BridgeConfig.setLzChainId(1, 2);

        assertEq(layerZeroV2BridgeConfig.evmToLzChainId(1), 2);
        assertEq(layerZeroV2BridgeConfig.lzToEvmChainId(2), 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 2));
        layerZeroV2BridgeConfig.evmToLzChainId(2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzChainIdNotRegistered.selector, 1));
        layerZeroV2BridgeConfig.lzToEvmChainId(1);
    }

    function test_SetLzChainId_ReassignEvmChainId() public {
        vm.startPrank(dao);

        layerZeroV2BridgeConfig.setLzChainId(1, 1);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.LzChainIdRegistered(2, 1);
        layerZeroV2BridgeConfig.setLzChainId(2, 1);

        assertEq(layerZeroV2BridgeConfig.evmToLzChainId(2), 1);
        assertEq(layerZeroV2BridgeConfig.lzToEvmChainId(1), 2);

        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 1));
        layerZeroV2BridgeConfig.evmToLzChainId(1);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzChainIdNotRegistered.selector, 2));
        layerZeroV2BridgeConfig.lzToEvmChainId(2);
    }
}
