// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

abstract contract MakinaGovernable_Util_Concrete_Test is Unit_Concrete_Test {
    IMakinaGovernable internal governable;

    function setUp() public virtual override {}

    function test_MakinaGovernableGetters() public view {
        assertEq(governable.mechanic(), mechanic);
        assertEq(governable.securityCouncil(), securityCouncil);
        assertEq(governable.riskManager(), riskManager);
        assertEq(governable.riskManagerTimelock(), riskManagerTimelock);
        assertFalse(governable.recoveryMode());
    }

    function test_SetMechanic_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        governable.setMechanic(address(0));
    }

    function test_SetMechanic() public {
        address newMechanic = makeAddr("NewMechanic");
        vm.expectEmit(true, true, false, false, address(governable));
        emit IMakinaGovernable.MechanicChanged(mechanic, newMechanic);
        vm.prank(dao);
        governable.setMechanic(newMechanic);
        assertEq(governable.mechanic(), newMechanic);
    }

    function test_SetSecurityCouncil_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        governable.setSecurityCouncil(address(0));
    }

    function test_SetSecurityCouncil() public {
        address newSecurityCouncil = makeAddr("NewSecurityCouncil");
        vm.expectEmit(true, true, false, false, address(governable));
        emit IMakinaGovernable.SecurityCouncilChanged(securityCouncil, newSecurityCouncil);
        vm.prank(dao);
        governable.setSecurityCouncil(newSecurityCouncil);
        assertEq(governable.securityCouncil(), newSecurityCouncil);
    }

    function test_SetRiskManager_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        governable.setRiskManager(address(0));
    }

    function test_SetRiskManager() public {
        address newRiskManager = makeAddr("NewRiskManager");
        vm.expectEmit(true, true, false, false, address(governable));
        emit IMakinaGovernable.RiskManagerChanged(riskManager, newRiskManager);
        vm.prank(dao);
        governable.setRiskManager(newRiskManager);
        assertEq(governable.riskManager(), newRiskManager);
    }

    function test_SetRiskManagerTimelock_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        governable.setRiskManagerTimelock(address(0));
    }

    function test_SetRiskManagerTimelock() public {
        address newRiskManagerTimelock = makeAddr("NewRiskManagerTimelock");
        vm.expectEmit(true, true, false, false, address(governable));
        emit IMakinaGovernable.RiskManagerTimelockChanged(riskManagerTimelock, newRiskManagerTimelock);
        vm.prank(dao);
        governable.setRiskManagerTimelock(newRiskManagerTimelock);
        assertEq(governable.riskManagerTimelock(), newRiskManagerTimelock);
    }

    function test_SetRecoveryMode_RevertWhen_CallerNotSC() public {
        vm.expectRevert(IMakinaGovernable.UnauthorizedCaller.selector);
        governable.setRecoveryMode(true);
    }

    function test_SetRecoveryMode() public {
        vm.expectEmit(true, false, false, false, address(governable));
        emit IMakinaGovernable.RecoveryModeChanged(true);
        vm.prank(securityCouncil);
        governable.setRecoveryMode(true);
        assertTrue(governable.recoveryMode());
    }
}
