// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ILayerZeroV2Config} from "src/interfaces/ILayerZeroV2Config.sol";
import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2Config_Unit_Concrete_Test} from "../LayerZeroV2Config.t.sol";

contract SetToken_Unit_Concrete_Test is LayerZeroV2Config_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        layerZeroV2Config.setForeignToken(address(0), 0, address(0));
    }

    function test_RevertWhen_ZeroTokenAddress() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroTokenAddress.selector));
        layerZeroV2Config.setForeignToken(address(0), 1, address(1));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroTokenAddress.selector));
        layerZeroV2Config.setForeignToken(address(0), 0, address(1));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroTokenAddress.selector));
        layerZeroV2Config.setForeignToken(address(1), 1, address(0));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroTokenAddress.selector));
        layerZeroV2Config.setForeignToken(address(1), 0, address(0));
    }

    function test_RevertWhen_ZeroChainId() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        layerZeroV2Config.setForeignToken(address(1), 0, address(2));
    }

    function test_SetToken_DifferentAddresses() public {
        vm.expectEmit(true, true, true, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.ForeignTokenRegistered(address(1), 2, address(2));
        vm.prank(dao);
        layerZeroV2Config.setForeignToken(address(1), 2, address(2));

        assertEq(layerZeroV2Config.getForeignToken(address(1), 2), address(2));
    }

    function test_SetToken_SameAddresses() public {
        vm.expectEmit(true, true, true, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.ForeignTokenRegistered(address(1), 2, address(1));
        vm.prank(dao);
        layerZeroV2Config.setForeignToken(address(1), 2, address(1));

        assertEq(layerZeroV2Config.getForeignToken(address(1), 2), address(1));
    }

    function test_SetToken_ReassignForeignToken() public {
        vm.startPrank(dao);

        layerZeroV2Config.setForeignToken(address(1), 2, address(1));

        vm.expectEmit(true, true, true, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.ForeignTokenRegistered(address(1), 2, address(2));
        layerZeroV2Config.setForeignToken(address(1), 2, address(2));

        assertEq(layerZeroV2Config.getForeignToken(address(1), 2), address(2));
    }

    function test_SetToken_ReassignLocalToken() public {
        vm.startPrank(dao);

        layerZeroV2Config.setForeignToken(address(1), 2, address(1));

        vm.expectEmit(true, true, true, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.ForeignTokenRegistered(address(2), 2, address(1));
        layerZeroV2Config.setForeignToken(address(2), 2, address(1));

        assertEq(layerZeroV2Config.getForeignToken(address(2), 2), address(1));

        vm.expectRevert(abi.encodeWithSelector(Errors.LzForeignTokenNotRegistered.selector, address(1), 2));
        layerZeroV2Config.getForeignToken(address(1), 2);
    }
}
