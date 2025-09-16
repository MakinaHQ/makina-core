// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {TokenRegistry_Unit_Concrete_Test} from "../TokenRegistry.t.sol";

contract GetLocalToken_Unit_Concrete_Test is TokenRegistry_Unit_Concrete_Test {
    function test_RevertWhen_TokenNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.LocalTokenNotRegistered.selector, address(0), 0));
        tokenRegistry.getLocalToken(address(0), 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.LocalTokenNotRegistered.selector, address(2), 2));
        tokenRegistry.getLocalToken(address(2), 2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LocalTokenNotRegistered.selector, address(1), 1));
        tokenRegistry.getLocalToken(address(1), 1);

        // associate local token 1 with foreign token 2 on foreign chain 2
        vm.prank(dao);
        tokenRegistry.setToken(address(1), 2, address(2));

        vm.expectRevert(abi.encodeWithSelector(Errors.LocalTokenNotRegistered.selector, address(1), 2));
        tokenRegistry.getLocalToken(address(1), 2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LocalTokenNotRegistered.selector, address(1), 1));
        tokenRegistry.getLocalToken(address(1), 1);
    }

    function test_GetLocalToken() public {
        vm.prank(dao);
        tokenRegistry.setToken(address(1), 2, address(2));

        assertEq(tokenRegistry.getLocalToken(address(2), 2), address(1));
    }
}
