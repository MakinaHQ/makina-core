// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IMachine} from "src/interfaces/IMachine.sol";
import {Constants} from "src/libraries/Constants.sol";

import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

contract Machine_Unit_Concrete_Test is Unit_Concrete_Hub_Test {
    function test_Getters() public view {
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.depositor(), machineDepositor);
        assertEq(machine.redeemer(), machineRedeemer);
        assertEq(machine.maxMint(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(machine.lastTotalAum(), 0);
        assertEq(machine.lastGlobalAccountingTime(), 0);
        assertEq(machine.hubCaliber(), address(caliber));
        assertTrue(machine.isIdleToken(address(accountingToken)));
        assertEq(machine.getSpokeCalibersLength(), 0);
    }

    function test_ConvertToShares() public view {
        // should hold when no yield occurred
        assertEq(machine.convertToShares(10 ** accountingToken.decimals()), 10 ** Constants.SHARE_TOKEN_DECIMALS);
    }

    function test_SetMechanic_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setMechanic(address(0));
    }

    function test_SetMechanic() public {
        address newMechanic = makeAddr("NewMechanic");
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.MechanicChanged(mechanic, newMechanic);
        vm.prank(dao);
        machine.setMechanic(newMechanic);
        assertEq(machine.mechanic(), newMechanic);
    }

    function test_SetSecurityCouncil_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setSecurityCouncil(address(0));
    }

    function test_SetSecurityCouncil() public {
        address newSecurityCouncil = makeAddr("NewSecurityCouncil");
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.SecurityCouncilChanged(securityCouncil, newSecurityCouncil);
        vm.prank(dao);
        machine.setSecurityCouncil(newSecurityCouncil);
        assertEq(machine.securityCouncil(), newSecurityCouncil);
    }

    function test_SetDepositor_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setDepositor(address(0));
    }

    function test_SetDepositor() public {
        address newDepositor = makeAddr("NewDepositor");
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.DepositorChanged(machineDepositor, newDepositor);
        vm.prank(dao);
        machine.setDepositor(newDepositor);
        assertEq(machine.depositor(), newDepositor);
    }

    function test_SetRedeemer_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setRedeemer(address(0));
    }

    function test_SetRedeemer() public {
        address newRedeemer = makeAddr("NewRedeemer");
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.RedeemerChanged(machineRedeemer, newRedeemer);
        vm.prank(dao);
        machine.setRedeemer(newRedeemer);
        assertEq(machine.redeemer(), newRedeemer);
    }

    function test_SetCaliberStaleThreshold_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setCaliberStaleThreshold(2 hours);
    }

    function test_SetCaliberStaleThreshold() public {
        uint256 newThreshold = 2 hours;
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.CaliberStaleThresholdChanged(DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD, newThreshold);
        vm.prank(dao);
        machine.setCaliberStaleThreshold(newThreshold);
        assertEq(machine.caliberStaleThreshold(), newThreshold);
    }

    function test_SetShareLimit_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setShareLimit(1e18);
    }

    function test_SetShareLimit() public {
        uint256 newShareLimit = 1e18;
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.ShareLimitChanged(DEFAULT_MACHINE_SHARE_LIMIT, newShareLimit);
        vm.prank(dao);
        machine.setShareLimit(newShareLimit);
        assertEq(machine.shareLimit(), newShareLimit);
    }

    function test_SetRecoveryMode_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setRecoveryMode(true);
    }

    function test_SetRecoveryMode() public {
        vm.expectEmit(true, false, false, true, address(machine));
        emit IMachine.RecoveryModeChanged(true);
        vm.prank(dao);
        machine.setRecoveryMode(true);
        assertTrue(machine.recoveryMode());
    }
}
