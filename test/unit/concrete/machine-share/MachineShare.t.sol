// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {DecimalsUtils} from "src/libraries/DecimalsUtils.sol";

import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

abstract contract MachineShare_Unit_Concrete_Test is Unit_Concrete_Hub_Test {
    IMachineShare internal shareToken;

    function setUp() public virtual override {
        Unit_Concrete_Hub_Test.setUp();

        shareToken = IMachineShare(machine.shareToken());
    }
}

contract MachineShare_Getters_Unit_Concrete_Test is MachineShare_Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
        assertEq(shareToken.decimals(), DecimalsUtils.SHARE_TOKEN_DECIMALS);
    }
}
