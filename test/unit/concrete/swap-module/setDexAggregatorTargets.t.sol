// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ISwapModule} from "src/interfaces/ISwapModule.sol";

import {SwapModule_Unit_Concrete_Test} from "./SwapModule.t.sol";

contract SetSwapperTargets_Unit_Concrete_Test is SwapModule_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        swapModule.setSwapperTargets(ISwapModule.Swapper.ZEROX, address(0), address(0));
    }

    function test_SetSwapperTargets() public {
        address newApprovalTarget = makeAddr("newApprovalTarget");
        address newExecutionTarget = makeAddr("newExecutionTarget");

        vm.expectEmit(true, true, true, true, address(swapModule));
        emit ISwapModule.SwapperTargetsSet(ISwapModule.Swapper.ZEROX, newApprovalTarget, newExecutionTarget);
        vm.prank(dao);
        swapModule.setSwapperTargets(ISwapModule.Swapper.ZEROX, newApprovalTarget, newExecutionTarget);
        (address approvalTarget, address executionTarget) = swapModule.swapperTargets(ISwapModule.Swapper.ZEROX);
        assertEq(approvalTarget, newApprovalTarget);
        assertEq(executionTarget, newExecutionTarget);
    }
}
