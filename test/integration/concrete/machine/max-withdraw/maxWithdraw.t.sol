// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract MaxWithdraw_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_MaxWithdraw_NoAssets() public view {
        assertEq(machine.maxWithdraw(), 0);
    }

    function test_MaxMint_AssetsInMachine() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount);
        assertEq(machine.maxWithdraw(), inputAmount);
    }

    function test_MaxMint_AssetsInMachineAndCaliber() public {
        uint256 inputAmount1 = 3e18;
        uint256 inputAmount2 = 1e18;
        deal(address(accountingToken), address(machine), inputAmount1);
        vm.prank(mechanic);
        machine.transferToCaliber(address(accountingToken), inputAmount2, block.chainid);
        assertEq(machine.maxWithdraw(), inputAmount1 - inputAmount2);
    }
}
