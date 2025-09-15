// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IMachineShare} from "src/interfaces/IMachineShare.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract MaxMint_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_MaxMint_ShareLimitEqualMaxUint() public view {
        assertEq(machine.shareLimit(), type(uint256).max);
        assertEq(machine.maxMint(), type(uint256).max);
    }

    function test_MaxMint_ShareLimitGreaterThanShareSupply() public {
        address shareToken = machine.shareToken();
        uint256 newShareLimit = 1e20;
        uint256 newShareSupply = 1e18;

        vm.prank(riskManager);
        machine.setShareLimit(newShareLimit);
        assertEq(machine.maxMint(), newShareLimit);

        vm.prank(address(machine));
        IMachineShare(shareToken).mint(address(this), newShareSupply);
        assertEq(machine.maxMint(), newShareLimit - newShareSupply);
    }

    function test_MaxMint_ShareLimitSmallerThanShareSupply() public {
        address shareToken = machine.shareToken();
        uint256 newShareLimit = 1e18;
        uint256 newShareSupply = 1e20;

        vm.prank(riskManager);
        machine.setShareLimit(newShareLimit);
        assertEq(machine.maxMint(), newShareLimit);

        vm.prank(address(machine));
        IMachineShare(shareToken).mint(address(this), newShareSupply);
        assertEq(machine.maxMint(), 0);
    }
}
