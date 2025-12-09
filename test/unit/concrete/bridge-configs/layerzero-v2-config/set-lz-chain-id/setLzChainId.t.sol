// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ILayerZeroV2Config} from "src/interfaces/ILayerZeroV2Config.sol";
import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2Config_Unit_Concrete_Test} from "../LayerZeroV2Config.t.sol";

contract SetLzChainId_Unit_Concrete_Test is LayerZeroV2Config_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        layerZeroV2Config.setLzChainId(0, 0);
    }

    function test_RevertWhen_ZeroChainId() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        layerZeroV2Config.setLzChainId(0, 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        layerZeroV2Config.setLzChainId(1, 0);
    }

    function test_SetLzChainId_DifferentIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.LzChainIdRegistered(1, 2);
        layerZeroV2Config.setLzChainId(1, 2);

        assertEq(layerZeroV2Config.evmToLzChainId(1), 2);
        assertEq(layerZeroV2Config.lzToEvmChainId(2), 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 2));
        layerZeroV2Config.evmToLzChainId(2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzChainIdNotRegistered.selector, 1));
        layerZeroV2Config.lzToEvmChainId(1);
    }

    function test_SetLzChainId_SameIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.LzChainIdRegistered(2, 2);
        layerZeroV2Config.setLzChainId(2, 2);

        assertEq(layerZeroV2Config.evmToLzChainId(2), 2);
        assertEq(layerZeroV2Config.lzToEvmChainId(2), 2);
    }

    function test_SetLzChainId_ReassignLzChainId() public {
        vm.startPrank(dao);

        layerZeroV2Config.setLzChainId(1, 1);

        vm.expectEmit(true, true, false, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.LzChainIdRegistered(1, 2);
        layerZeroV2Config.setLzChainId(1, 2);

        assertEq(layerZeroV2Config.evmToLzChainId(1), 2);
        assertEq(layerZeroV2Config.lzToEvmChainId(2), 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 2));
        layerZeroV2Config.evmToLzChainId(2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzChainIdNotRegistered.selector, 1));
        layerZeroV2Config.lzToEvmChainId(1);
    }

    function test_SetLzChainId_ReassignEvmChainId() public {
        vm.startPrank(dao);

        layerZeroV2Config.setLzChainId(1, 1);

        vm.expectEmit(true, true, false, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.LzChainIdRegistered(2, 1);
        layerZeroV2Config.setLzChainId(2, 1);

        assertEq(layerZeroV2Config.evmToLzChainId(2), 1);
        assertEq(layerZeroV2Config.lzToEvmChainId(1), 2);

        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 1));
        layerZeroV2Config.evmToLzChainId(1);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzChainIdNotRegistered.selector, 2));
        layerZeroV2Config.lzToEvmChainId(2);
    }
}
