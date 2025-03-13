// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IChainRegistry} from "src/interfaces/IChainRegistry.sol";

import {ChainRegistry_Unit_Concrete_Test} from "../ChainRegistry.t.sol";

contract SetChainIds_Unit_Concrete_Test is ChainRegistry_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        chainRegistry.setChainIds(0, 0);
    }

    function test_RevertWhen_ZeroChainId() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(IChainRegistry.ZeroChainId.selector));
        chainRegistry.setChainIds(0, 1);

        vm.expectRevert(abi.encodeWithSelector(IChainRegistry.ZeroChainId.selector));
        chainRegistry.setChainIds(1, 0);
    }

    function test_SetChainIds_DifferentIds() public {
        vm.startPrank(dao);

        chainRegistry.setChainIds(1, 2);
        assertEq(chainRegistry.evmToWhChainId(1), 2);
        assertEq(chainRegistry.whToEvmChainId(2), 1);
    }

    function test_SetChainIds_SameIds() public {
        vm.startPrank(dao);

        chainRegistry.setChainIds(2, 2);
        assertEq(chainRegistry.evmToWhChainId(2), 2);
        assertEq(chainRegistry.whToEvmChainId(2), 2);
    }
}
