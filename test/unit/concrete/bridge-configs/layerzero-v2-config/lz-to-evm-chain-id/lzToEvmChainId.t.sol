// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeConfig_Unit_Concrete_Test} from "../LayerZeroV2BridgeConfig.t.sol";

contract LzToEvmChainId_Unit_Concrete_Test is LayerZeroV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_LzChainIdNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.LzChainIdNotRegistered.selector, 0));
        layerZeroV2BridgeConfig.lzToEvmChainId(0);

        vm.expectRevert(abi.encodeWithSelector(Errors.LzChainIdNotRegistered.selector, 1));
        layerZeroV2BridgeConfig.lzToEvmChainId(1);
    }

    function test_LzToEvmChainId() public {
        vm.prank(dao);
        layerZeroV2BridgeConfig.setLzChainId(1, 2);

        assertEq(layerZeroV2BridgeConfig.lzToEvmChainId(2), 1);
    }
}
