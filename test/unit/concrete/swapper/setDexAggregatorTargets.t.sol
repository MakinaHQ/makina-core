// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

import {Swapper_Unit_Concrete_Test} from "./Swapper.t.sol";

contract SetDexAggregatorTargets_Unit_Concrete_Test is Swapper_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(0), address(0));
    }

    function test_SetDexAggregatorTargets() public {
        address newApprovalTarget = makeAddr("newApprovalTarget");
        address newExecutionTarget = makeAddr("newExecutionTarget");

        vm.expectEmit(true, true, true, true, address(swapper));
        emit ISwapper.DexAggregatorTargetsSet(ISwapper.DexAggregator.ZEROX, newApprovalTarget, newExecutionTarget);
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, newApprovalTarget, newExecutionTarget);
        (address approvalTarget, address executionTarget) = swapper.dexAggregatorTargets(ISwapper.DexAggregator.ZEROX);
        assertEq(approvalTarget, newApprovalTarget);
        assertEq(executionTarget, newExecutionTarget);
    }
}
