// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {ChainRegistry_Unit_Concrete_Test} from "../ChainRegistry.t.sol";

contract WhToEvmChainId_Unit_Concrete_Test is ChainRegistry_Unit_Concrete_Test {
    function test_RevertWhen_WhChainIdNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.WhChainIdNotRegistered.selector, 0));
        chainRegistry.whToEvmChainId(0);

        vm.expectRevert(abi.encodeWithSelector(Errors.WhChainIdNotRegistered.selector, 1));
        chainRegistry.whToEvmChainId(1);
    }

    function test_WhToEvmChainId() public {
        vm.prank(dao);
        chainRegistry.setChainIds(1, 2);

        assertEq(chainRegistry.whToEvmChainId(2), 1);
    }
}
