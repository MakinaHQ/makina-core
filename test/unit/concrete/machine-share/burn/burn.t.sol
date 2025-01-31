// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineShare} from "src/interfaces/IMachineShare.sol";

import {MachineShare_Unit_Concrete_Test} from "../MachineShare.t.sol";

contract Burn_Unit_Concrete_Test is MachineShare_Unit_Concrete_Test {
    function test_cannotBurnWithoutMachine() public {
        uint256 amount = 100;
        deal(address(shareToken), address(this), amount, true);

        vm.expectRevert(IMachineShare.NotMachine.selector);
        shareToken.burn(address(this), amount);
    }

    function test_burn() public {
        uint256 amount = 100;
        deal(address(shareToken), address(this), amount, true);

        vm.prank(address(machine));
        shareToken.burn(address(this), amount);
        assertEq(shareToken.balanceOf(address(this)), 0);
    }
}
