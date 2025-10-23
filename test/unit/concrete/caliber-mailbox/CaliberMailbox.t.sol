// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";

import {MakinaGovernable_Unit_Concrete_Test} from "../makina-governable/MakinaGovernable.t.sol";

import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract MakinaGovernable_CaliberMailbox_Unit_Concrete_Test is
    MakinaGovernable_Unit_Concrete_Test,
    Unit_Concrete_Spoke_Test
{
    function setUp() public override(MakinaGovernable_Unit_Concrete_Test, Unit_Concrete_Spoke_Test) {
        Unit_Concrete_Spoke_Test.setUp();
        governable = IMakinaGovernable(address(caliberMailbox));
    }
}

contract Getters_Setters_CaliberMailbox_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    function test_Getters() public view {
        vm.assertEq(caliberMailbox.cooldownDuration(), DEFAULT_CALIBER_COOLDOWN_DURATION);
    }

    function test_SetCooldownDuration_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.setCooldownDuration(0);
    }

    function test_SetCooldownDuration() public {
        uint256 newCooldownDuration = DEFAULT_CALIBER_COOLDOWN_DURATION + 1 days;

        vm.expectEmit(true, true, false, false, address(caliberMailbox));
        emit ICaliberMailbox.CooldownDurationChanged(DEFAULT_CALIBER_COOLDOWN_DURATION, newCooldownDuration);
        vm.prank(riskManagerTimelock);
        caliberMailbox.setCooldownDuration(newCooldownDuration);

        assertEq(caliberMailbox.cooldownDuration(), newCooldownDuration);
    }
}
