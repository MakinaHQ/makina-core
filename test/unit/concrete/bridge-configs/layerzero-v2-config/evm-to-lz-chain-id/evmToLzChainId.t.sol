// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2Config_Unit_Concrete_Test} from "../LayerZeroV2Config.t.sol";

contract EvmToLzChainId_Unit_Concrete_Test is LayerZeroV2Config_Unit_Concrete_Test {
    function test_RevertWhen_EvmChainIdNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 0));
        layerZeroV2Config.evmToLzChainId(0);

        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 1));
        layerZeroV2Config.evmToLzChainId(1);
    }

    function test_EvmToLzChainId() public {
        vm.prank(dao);
        layerZeroV2Config.setLzChainId(1, 2);

        assertEq(layerZeroV2Config.evmToLzChainId(1), 2);
    }
}
