// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IMachine} from "src/interfaces/IMachine.sol";
import {Constants} from "src/libraries/Constants.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract Machine_Unit_Concrete_Test is Unit_Concrete_Test {
    function setUp() public virtual override {
        Unit_Concrete_Test.setUp();

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine,) = _deployMachine(address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));
    }

    function test_Getters() public view {
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.maxMint(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(machine.lastTotalAum(), 0);
        assertEq(machine.lastGlobalAccountingTime(), 0);
        assertEq(machine.getCalibersLength(), 1);
        assertEq(machine.getSupportedChainId(0), block.chainid);
        assertNotEq(machine.getMailbox(block.chainid), address(0));
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_ConvertToShares() public view {
        // should hold when no yield occurred
        assertEq(machine.convertToShares(10 ** accountingToken.decimals()), 10 ** Constants.SHARE_TOKEN_DECIMALS);
    }

    function test_SetMechanic_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setMechanic(address(0x0));
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
        machine.setSecurityCouncil(address(0x0));
    }

    function test_SetSecurityCouncil() public {
        address newSecurityCouncil = makeAddr("NewSecurityCouncil");
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.SecurityCouncilChanged(securityCouncil, newSecurityCouncil);
        vm.prank(dao);
        machine.setSecurityCouncil(newSecurityCouncil);
        assertEq(machine.securityCouncil(), newSecurityCouncil);
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

    function test_SetDepositorOnlyMode_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setDepositorOnlyMode(true);
    }

    function test_SetDepositorOnlyMode() public {
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.DepositorOnlyModeChanged(true);
        vm.prank(dao);
        machine.setDepositorOnlyMode(true);
        assertTrue(machine.depositorOnlyMode());
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
