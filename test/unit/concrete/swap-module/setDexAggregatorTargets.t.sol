// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ISwapModule} from "src/interfaces/ISwapModule.sol";

import {SwapModule_Unit_Concrete_Test} from "./SwapModule.t.sol";

contract SetDexAggregatorTargets_Unit_Concrete_Test is SwapModule_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        swapModule.setDexAggregatorTargets(ISwapModule.DexAggregator.ZEROX, address(0), address(0));
    }

    function test_SetDexAggregatorTargets() public {
        address newApprovalTarget = makeAddr("newApprovalTarget");
        address newExecutionTarget = makeAddr("newExecutionTarget");

        vm.expectEmit(true, true, true, true, address(swapModule));
        emit ISwapModule.DexAggregatorTargetsSet(ISwapModule.DexAggregator.ZEROX, newApprovalTarget, newExecutionTarget);
        vm.prank(dao);
        swapModule.setDexAggregatorTargets(ISwapModule.DexAggregator.ZEROX, newApprovalTarget, newExecutionTarget);
        (address approvalTarget, address executionTarget) =
            swapModule.dexAggregatorTargets(ISwapModule.DexAggregator.ZEROX);
        assertEq(approvalTarget, newApprovalTarget);
        assertEq(executionTarget, newExecutionTarget);
    }
}
