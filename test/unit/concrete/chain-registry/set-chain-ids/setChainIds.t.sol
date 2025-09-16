// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IChainRegistry} from "src/interfaces/IChainRegistry.sol";
import {Errors} from "src/libraries/Errors.sol";

import {ChainRegistry_Unit_Concrete_Test} from "../ChainRegistry.t.sol";

contract SetChainIds_Unit_Concrete_Test is ChainRegistry_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        chainRegistry.setChainIds(0, 0);
    }

    function test_RevertWhen_ZeroChainId() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        chainRegistry.setChainIds(0, 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        chainRegistry.setChainIds(1, 0);
    }

    function test_SetChainIds_DifferentIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(chainRegistry));
        emit IChainRegistry.ChainIdsRegistered(1, 2);
        chainRegistry.setChainIds(1, 2);

        assertTrue(chainRegistry.isEvmChainIdRegistered(1));
        assertFalse(chainRegistry.isWhChainIdRegistered(1));
        assertTrue(chainRegistry.isWhChainIdRegistered(2));
        assertFalse(chainRegistry.isEvmChainIdRegistered(2));
        assertEq(chainRegistry.evmToWhChainId(1), 2);
        assertEq(chainRegistry.whToEvmChainId(2), 1);
    }

    function test_SetChainIds_SameIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(chainRegistry));
        emit IChainRegistry.ChainIdsRegistered(2, 2);
        chainRegistry.setChainIds(2, 2);

        assertTrue(chainRegistry.isEvmChainIdRegistered(2));
        assertTrue(chainRegistry.isWhChainIdRegistered(2));
        assertEq(chainRegistry.evmToWhChainId(2), 2);
        assertEq(chainRegistry.whToEvmChainId(2), 2);
    }

    function test_SetChainIds_ReassignWhChainId() public {
        vm.startPrank(dao);

        chainRegistry.setChainIds(1, 1);

        vm.expectEmit(true, true, false, false, address(chainRegistry));
        emit IChainRegistry.ChainIdsRegistered(1, 2);
        chainRegistry.setChainIds(1, 2);

        assertTrue(chainRegistry.isEvmChainIdRegistered(1));
        assertTrue(chainRegistry.isWhChainIdRegistered(2));

        assertFalse(chainRegistry.isEvmChainIdRegistered(2));
        assertFalse(chainRegistry.isWhChainIdRegistered(1));

        assertEq(chainRegistry.evmToWhChainId(1), 2);
        assertEq(chainRegistry.whToEvmChainId(2), 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.WhChainIdNotRegistered.selector, 1));
        chainRegistry.whToEvmChainId(1);
    }

    function test_SetChainIds_ReassignEvmChainId() public {
        vm.startPrank(dao);

        chainRegistry.setChainIds(1, 1);

        vm.expectEmit(true, true, false, false, address(chainRegistry));
        emit IChainRegistry.ChainIdsRegistered(2, 1);
        chainRegistry.setChainIds(2, 1);

        assertTrue(chainRegistry.isEvmChainIdRegistered(2));
        assertTrue(chainRegistry.isWhChainIdRegistered(1));

        assertFalse(chainRegistry.isEvmChainIdRegistered(1));
        assertFalse(chainRegistry.isWhChainIdRegistered(2));

        assertEq(chainRegistry.evmToWhChainId(2), 1);
        assertEq(chainRegistry.whToEvmChainId(1), 2);

        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 1));
        chainRegistry.evmToWhChainId(1);
    }
}
