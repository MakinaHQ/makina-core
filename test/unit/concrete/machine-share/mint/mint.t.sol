// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineShare} from "src/interfaces/IMachineShare.sol";

import {MachineShare_Unit_Concrete_Test} from "../MachineShare.t.sol";

contract Mint_Unit_Concrete_Test is MachineShare_Unit_Concrete_Test {
    function test_RevertWhen_CallerNotMachine() public {
        uint256 amount = 100;

        vm.expectRevert(IMachineShare.NotMachine.selector);
        shareToken.mint(address(this), amount);
    }

    function test_Mint() public {
        uint256 amount = 100;

        vm.prank(address(machine));
        shareToken.mint(address(this), amount);
        assertEq(shareToken.balanceOf(address(this)), amount);
    }
}
