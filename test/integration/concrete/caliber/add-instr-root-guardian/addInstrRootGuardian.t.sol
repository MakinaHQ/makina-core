// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract AddInstrRootGuardian_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.addInstrRootGuardian(address(0));
    }

    function test_RevertWhen_TargetIsAlreadyRootGuardian() public {
        vm.startPrank(dao);

        vm.expectRevert(Errors.AlreadyRootGuardian.selector);
        caliber.addInstrRootGuardian(riskManager);

        vm.expectRevert(Errors.AlreadyRootGuardian.selector);
        caliber.addInstrRootGuardian(securityCouncil);

        address newGuardian = makeAddr("newGuardian");
        caliber.addInstrRootGuardian(newGuardian);

        vm.expectRevert(Errors.AlreadyRootGuardian.selector);
        caliber.addInstrRootGuardian(newGuardian);
    }

    function test_AddInstrRootGuardian() public {
        address newGuardian = makeAddr("newGuardian");

        vm.expectEmit(true, true, false, false, address(caliber));
        emit ICaliber.InstrRootGuardianAdded(newGuardian);
        vm.prank(dao);
        caliber.addInstrRootGuardian(newGuardian);

        assertTrue(caliber.isInstrRootGuardian(newGuardian));
    }
}
