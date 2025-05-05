// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract RemoveInstrRootGuardian_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.removeInstrRootGuardian(address(0));
    }

    function test_RevertWhen_TargetIsAlreadyRootGuardian() public {
        vm.expectRevert(Errors.NotRootGuardian.selector);
        vm.prank(dao);
        caliber.removeInstrRootGuardian(address(0));
    }

    function test_RevertWhen_TargetIsProtectedRootGuardian() public {
        vm.expectRevert(Errors.ProtectedRootGuardian.selector);
        vm.prank(dao);
        caliber.removeInstrRootGuardian(riskManager);

        vm.expectRevert(Errors.ProtectedRootGuardian.selector);
        vm.prank(dao);
        caliber.removeInstrRootGuardian(securityCouncil);
    }

    function test_RemoveInstrRootGuardian() public {
        address newGuardian = makeAddr("newGuardian");
        vm.prank(dao);
        caliber.addInstrRootGuardian(newGuardian);

        vm.expectEmit(true, true, false, false, address(caliber));
        emit ICaliber.InstrRootGuardianRemoved(newGuardian);
        vm.prank(dao);
        caliber.removeInstrRootGuardian(newGuardian);

        assertFalse(caliber.isInstrRootGuardian(newGuardian));
    }
}
