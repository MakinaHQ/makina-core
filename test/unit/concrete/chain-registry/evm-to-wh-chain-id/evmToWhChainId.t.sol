// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IChainRegistry} from "src/interfaces/IChainRegistry.sol";

import {ChainRegistry_Unit_Concrete_Test} from "../ChainRegistry.t.sol";

contract EvmToWhChainId_Unit_Concrete_Test is ChainRegistry_Unit_Concrete_Test {
    function test_RevertWhen_EvmChainIdNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(IChainRegistry.EvmChainIdNotRegistered.selector, 0));
        chainRegistry.evmToWhChainId(0);

        vm.expectRevert(abi.encodeWithSelector(IChainRegistry.EvmChainIdNotRegistered.selector, 1));
        chainRegistry.evmToWhChainId(1);
    }

    function test_EvmToWhChainId() public {
        vm.prank(dao);
        chainRegistry.setChainIds(1, 2);

        assertEq(chainRegistry.evmToWhChainId(1), 2);
    }
}
