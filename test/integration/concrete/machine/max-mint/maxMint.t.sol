// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineShare} from "src/interfaces/IMachineShare.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract MaxMint_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_maxMintWhenShareLimitEqualMaxUint() public view {
        assertEq(machine.shareLimit(), type(uint256).max);
        assertEq(machine.maxMint(), type(uint256).max);
    }

    function test_maxMintWhenShareLimitSmallerThanShareSupply() public {
        address shareToken = machine.shareToken();
        uint256 newShareLimit = 1e20;
        uint256 newShareSupply = 1e18;

        vm.prank(dao);
        machine.setShareLimit(newShareLimit);
        assertEq(machine.maxMint(), newShareLimit);

        vm.prank(address(machine));
        IMachineShare(shareToken).mint(address(this), newShareSupply);
        assertEq(machine.maxMint(), newShareLimit - newShareSupply);
    }

    function test_maxMintWhenShareLimitGreaterThanShareSupply() public {
        address shareToken = machine.shareToken();
        uint256 newShareLimit = 1e18;
        uint256 newShareSupply = 1e20;

        vm.prank(dao);
        machine.setShareLimit(newShareLimit);
        assertEq(machine.maxMint(), newShareLimit);

        vm.prank(address(machine));
        IMachineShare(shareToken).mint(address(this), newShareSupply);
        assertEq(machine.maxMint(), 0);
    }
}
