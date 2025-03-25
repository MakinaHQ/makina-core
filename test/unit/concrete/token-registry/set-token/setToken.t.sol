// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ITokenRegistry} from "src/interfaces/ITokenRegistry.sol";

import {TokenRegistry_Unit_Concrete_Test} from "../TokenRegistry.t.sol";

contract SetToken_Unit_Concrete_Test is TokenRegistry_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        tokenRegistry.setToken(address(0), 0, address(0));
    }

    function test_RevertWhen_ZeroTokenAddress() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(ITokenRegistry.ZeroTokenAddress.selector));
        tokenRegistry.setToken(address(0), 1, address(1));

        vm.expectRevert(abi.encodeWithSelector(ITokenRegistry.ZeroTokenAddress.selector));
        tokenRegistry.setToken(address(0), 0, address(1));

        vm.expectRevert(abi.encodeWithSelector(ITokenRegistry.ZeroTokenAddress.selector));
        tokenRegistry.setToken(address(1), 1, address(0));

        vm.expectRevert(abi.encodeWithSelector(ITokenRegistry.ZeroTokenAddress.selector));
        tokenRegistry.setToken(address(1), 0, address(0));
    }

    function test_RevertWhen_ZeroChainId() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(ITokenRegistry.ZeroChainId.selector));
        tokenRegistry.setToken(address(1), 0, address(2));
    }

    function test_SetToken_DifferentAddresses() public {
        vm.expectEmit(true, true, true, false, address(tokenRegistry));
        emit ITokenRegistry.TokenRegistered(address(1), 2, address(1));
        vm.prank(dao);
        tokenRegistry.setToken(address(1), 2, address(1));

        assertEq(tokenRegistry.getForeignToken(address(1), 2), address(1));
        assertEq(tokenRegistry.getLocalToken(address(1), 2), address(1));
    }

    function test_SetToken_SameAddresses() public {
        vm.expectEmit(true, true, true, false, address(tokenRegistry));
        emit ITokenRegistry.TokenRegistered(address(1), 2, address(2));
        vm.prank(dao);
        tokenRegistry.setToken(address(1), 2, address(2));

        assertEq(tokenRegistry.getForeignToken(address(1), 2), address(2));
        assertEq(tokenRegistry.getLocalToken(address(2), 2), address(1));
    }
}
