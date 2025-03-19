// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {Constants} from "src/libraries/Constants.sol";

import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

contract MachineShare_Unit_Concrete_Test is Unit_Concrete_Hub_Test {
    IMachineShare internal shareToken;

    function setUp() public override {
        Unit_Concrete_Hub_Test.setUp();

        shareToken = IMachineShare(machine.shareToken());
    }

    function test_Getters() public view {
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
        assertEq(shareToken.decimals(), Constants.SHARE_TOKEN_DECIMALS);
    }
}
