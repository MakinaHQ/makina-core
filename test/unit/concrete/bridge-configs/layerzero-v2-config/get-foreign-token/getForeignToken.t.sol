// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeConfig_Unit_Concrete_Test} from "../LayerZeroV2BridgeConfig.t.sol";

contract GetForeignToken_Unit_Concrete_Test is LayerZeroV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_TokenNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.LzForeignTokenNotRegistered.selector, address(0), 0));
        layerZeroV2BridgeConfig.getForeignToken(address(0), 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzForeignTokenNotRegistered.selector, address(2), 2));
        layerZeroV2BridgeConfig.getForeignToken(address(2), 2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzForeignTokenNotRegistered.selector, address(1), 1));
        layerZeroV2BridgeConfig.getForeignToken(address(1), 1);

        // associate local token 1 with foreign token 2 on foreign chain 2
        vm.prank(dao);
        layerZeroV2BridgeConfig.setForeignToken(address(1), 2, address(2));

        vm.expectRevert(abi.encodeWithSelector(Errors.LzForeignTokenNotRegistered.selector, address(2), 2));
        layerZeroV2BridgeConfig.getForeignToken(address(2), 2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzForeignTokenNotRegistered.selector, address(1), 1));
        layerZeroV2BridgeConfig.getForeignToken(address(1), 1);
    }

    function test_GetForeignToken() public {
        vm.prank(dao);
        layerZeroV2BridgeConfig.setForeignToken(address(1), 2, address(2));

        assertEq(layerZeroV2BridgeConfig.getForeignToken(address(1), 2), address(2));
    }
}
