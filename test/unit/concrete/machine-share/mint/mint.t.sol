// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {MachineShare_Unit_Concrete_Test} from "../MachineShare.t.sol";

contract Mint_Unit_Concrete_Test is MachineShare_Unit_Concrete_Test {
    function test_RevertWhen_CallerNotMinter() public {
        uint256 amount = 100;

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        shareToken.mint(address(this), amount);
    }

    function test_Mint() public {
        uint256 amount = 100;

        vm.prank(address(machine));
        shareToken.mint(address(this), amount);
        assertEq(shareToken.balanceOf(address(this)), amount);
    }
}
