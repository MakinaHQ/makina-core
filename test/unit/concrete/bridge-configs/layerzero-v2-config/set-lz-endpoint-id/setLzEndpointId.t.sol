// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ILayerZeroV2BridgeConfig} from "src/interfaces/ILayerZeroV2BridgeConfig.sol";
import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeConfig_Unit_Concrete_Test} from "../LayerZeroV2BridgeConfig.t.sol";

contract SetLzEndpointId_Unit_Concrete_Test is LayerZeroV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        layerZeroV2BridgeConfig.setLzEndpointId(0, 0);
    }

    function test_RevertWhen_ZeroChainId() public {
        vm.prank(dao);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        layerZeroV2BridgeConfig.setLzEndpointId(0, 1);
    }

    function test_RevertWhen_ZeroLzEndpointId() public {
        vm.prank(dao);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroLzEndpointId.selector));
        layerZeroV2BridgeConfig.setLzEndpointId(1, 0);
    }

    function test_SetLzEndpointId_DifferentIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.LzEndpointIdRegistered(1, 2);
        layerZeroV2BridgeConfig.setLzEndpointId(1, 2);

        assertEq(layerZeroV2BridgeConfig.getLzEndpointId(1), 2);

        vm.expectRevert(Errors.LzEndpointIdNotRegistered.selector);
        layerZeroV2BridgeConfig.getLzEndpointId(2);
    }

    function test_SetLzEndpointId_SameIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.LzEndpointIdRegistered(2, 2);
        layerZeroV2BridgeConfig.setLzEndpointId(2, 2);

        assertEq(layerZeroV2BridgeConfig.getLzEndpointId(2), 2);
    }

    function test_SetLzEndpointId_ReassignLzEndpointId() public {
        vm.startPrank(dao);

        layerZeroV2BridgeConfig.setLzEndpointId(1, 1);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.LzEndpointIdRegistered(1, 2);
        layerZeroV2BridgeConfig.setLzEndpointId(1, 2);

        assertEq(layerZeroV2BridgeConfig.getLzEndpointId(1), 2);

        vm.expectRevert(Errors.LzEndpointIdNotRegistered.selector);
        layerZeroV2BridgeConfig.getLzEndpointId(2);
    }

    function test_SetLzEndpointId_ReassignEvmChainId() public {
        vm.startPrank(dao);

        layerZeroV2BridgeConfig.setLzEndpointId(1, 1);

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.LzEndpointIdRegistered(2, 1);
        layerZeroV2BridgeConfig.setLzEndpointId(2, 1);

        assertEq(layerZeroV2BridgeConfig.getLzEndpointId(2), 1);

        vm.expectRevert(Errors.LzEndpointIdNotRegistered.selector);
        layerZeroV2BridgeConfig.getLzEndpointId(1);
    }
}
