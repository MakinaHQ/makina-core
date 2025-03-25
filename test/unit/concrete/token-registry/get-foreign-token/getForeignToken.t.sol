// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ITokenRegistry} from "src/interfaces/ITokenRegistry.sol";

import {TokenRegistry_Unit_Concrete_Test} from "../TokenRegistry.t.sol";

contract GetForeignToken_Unit_Concrete_Test is TokenRegistry_Unit_Concrete_Test {
    function test_RevertWhen_TokenNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(ITokenRegistry.ForeignTokenNotRegistered.selector, address(0), 0));
        tokenRegistry.getForeignToken(address(0), 0);

        vm.expectRevert(abi.encodeWithSelector(ITokenRegistry.ForeignTokenNotRegistered.selector, address(2), 2));
        tokenRegistry.getForeignToken(address(2), 2);

        vm.expectRevert(abi.encodeWithSelector(ITokenRegistry.ForeignTokenNotRegistered.selector, address(1), 1));
        tokenRegistry.getForeignToken(address(1), 1);

        // associate local token 1 with foreign token 2 on foreign chain 2
        vm.prank(dao);
        tokenRegistry.setToken(address(1), 2, address(2));

        vm.expectRevert(abi.encodeWithSelector(ITokenRegistry.ForeignTokenNotRegistered.selector, address(2), 2));
        tokenRegistry.getForeignToken(address(2), 2);

        vm.expectRevert(abi.encodeWithSelector(ITokenRegistry.ForeignTokenNotRegistered.selector, address(1), 1));
        tokenRegistry.getForeignToken(address(1), 1);
    }

    function test_GetForeignToken() public {
        vm.prank(dao);
        tokenRegistry.setToken(address(1), 2, address(2));

        assertEq(tokenRegistry.getForeignToken(address(1), 2), address(2));
    }
}
