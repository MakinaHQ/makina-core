// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ISwapModule} from "src/interfaces/ISwapModule.sol";

import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract SetSwapperTargets_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        swapModule.setSwapperTargets(ZEROX_SWAPPER_ID, address(0), address(0));
    }

    function test_SetSwapperTargets() public {
        address newApprovalTarget = makeAddr("newApprovalTarget");
        address newExecutionTarget = makeAddr("newExecutionTarget");

        vm.expectEmit(true, true, true, true, address(swapModule));
        emit ISwapModule.SwapperTargetsSet(ZEROX_SWAPPER_ID, newApprovalTarget, newExecutionTarget);
        vm.prank(dao);
        swapModule.setSwapperTargets(ZEROX_SWAPPER_ID, newApprovalTarget, newExecutionTarget);
        (address approvalTarget, address executionTarget) = swapModule.getSwapperTargets(ZEROX_SWAPPER_ID);
        assertEq(approvalTarget, newApprovalTarget);
        assertEq(executionTarget, newExecutionTarget);
    }
}
