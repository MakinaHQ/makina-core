// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {MachineShare_Unit_Concrete_Test} from "../MachineShare.t.sol";

contract Burn_Unit_Concrete_Test is MachineShare_Unit_Concrete_Test {
    address private user;

    function setUp() public override {
        MachineShare_Unit_Concrete_Test.setUp();
        user = makeAddr("user");
    }

    function test_Burn_From_RevertWhen_CallerNotOwner() public {
        uint256 amount = 100;
        deal(address(shareToken), user, amount, true);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        shareToken.burn(user, amount);
    }

    function test_Burn_From() public {
        uint256 amount = 100;
        deal(address(shareToken), user, amount, true);

        vm.prank(address(machine));
        shareToken.burn(user, amount);
        assertEq(shareToken.balanceOf(user), 0);
        assertEq(shareToken.balanceOf(address(this)), 0);
    }

    function test_Burn_Self() public {
        uint256 amount = 100;
        deal(address(shareToken), address(this), amount, true);

        shareToken.burn(address(this), amount);
        assertEq(shareToken.balanceOf(address(this)), 0);
    }
}
