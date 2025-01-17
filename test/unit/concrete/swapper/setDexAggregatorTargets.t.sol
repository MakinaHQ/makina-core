// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ISwapper} from "src/interfaces/ISwapper.sol";

import {Swapper_Unit_Concrete_Test} from "./Swapper.t.sol";

contract SetDexAggregatorTargets_Unit_Concrete_Test is Swapper_Unit_Concrete_Test {
    function test_cannotSetDexAggregatorTargetsWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(0), address(0));
    }

    function test_setDexAggregatorTargets() public {
        vm.expectEmit(true, true, true, true, address(swapper));
        emit DexAggregatorTargetsSet(ISwapper.DexAggregator.ZEROX, address(1), address(2));
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(1), address(2));
        (address approvalTarget, address executionTarget) = swapper.dexAggregatorTargets(ISwapper.DexAggregator.ZEROX);
        assertEq(approvalTarget, address(1));
        assertEq(executionTarget, address(2));
    }
}
