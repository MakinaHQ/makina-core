// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeConfig_Unit_Concrete_Test} from "../LayerZeroV2BridgeConfig.t.sol";

contract GetLzEndpointId_Unit_Concrete_Test is LayerZeroV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_LzEndpointIdNotRegistered() public {
        vm.expectRevert(Errors.LzEndpointIdNotRegistered.selector);
        layerZeroV2BridgeConfig.getLzEndpointId(0);

        vm.expectRevert(Errors.LzEndpointIdNotRegistered.selector);
        layerZeroV2BridgeConfig.getLzEndpointId(1);
    }

    function test_GetLzEndpointId() public {
        vm.prank(dao);
        layerZeroV2BridgeConfig.setLzEndpointId(1, 2);

        assertEq(layerZeroV2BridgeConfig.getLzEndpointId(1), 2);
    }
}
