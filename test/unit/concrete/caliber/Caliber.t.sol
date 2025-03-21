// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";

import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract Caliber_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    bytes32 public defaultRoot;

    function setUp() public override {
        Unit_Concrete_Spoke_Test.setUp();

        (caliber,) = _deployCaliber(address(0), address(accountingToken), bytes32(0), address(0));

        defaultRoot = keccak256(abi.encodePacked("defaultRoot"));

        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(defaultRoot);
        skip(caliber.timelockDuration() + 1);
    }

    function test_Getters() public view {
        assertNotEq(caliber.mailbox(), address(0));
        assertEq(caliber.mechanic(), mechanic);
        assertEq(caliber.securityCouncil(), securityCouncil);
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.flashLoanModule(), address(0));
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
        assertEq(caliber.recoveryMode(), false);
        assertEq(caliber.allowedInstrRoot(), defaultRoot);
        assertEq(caliber.timelockDuration(), 1 hours);
        assertEq(caliber.pendingAllowedInstrRoot(), bytes32(0));
        assertEq(caliber.pendingTimelockExpiry(), 0);
        assertEq(caliber.maxPositionIncreaseLossBps(), DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS);
        assertEq(caliber.maxPositionDecreaseLossBps(), DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS);
        assertEq(caliber.maxSwapLossBps(), DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS);
        assertEq(caliber.isBaseToken(address(accountingToken)), true);
        assertEq(caliber.getPositionsLength(), 0);
        assertEq(caliber.getBaseTokensLength(), 1);
        assertEq(caliber.getBaseTokenAddress(0), address(accountingToken));
    }

    function test_SetMechanic_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMechanic(address(0x0));
    }

    function test_SetMechanic() public {
        address newMechanic = makeAddr("NewMechanic");
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.MechanicChanged(mechanic, newMechanic);
        vm.prank(dao);
        caliber.setMechanic(newMechanic);
        assertEq(caliber.mechanic(), newMechanic);
    }

    function test_SetSecurityCouncil_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setSecurityCouncil(address(0x0));
    }

    function test_SetSecurityCouncil() public {
        address newSecurityCouncil = makeAddr("NewSecurityCouncil");
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.SecurityCouncilChanged(securityCouncil, newSecurityCouncil);
        vm.prank(dao);
        caliber.setSecurityCouncil(newSecurityCouncil);
        assertEq(caliber.securityCouncil(), newSecurityCouncil);
    }

    function test_SetFlashLoanModule_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setFlashLoanModule(address(0x0));
    }

    function test_SetFlashLoanModule() public {
        address newFlashLoanModule = makeAddr("NewFlashLoanModule");
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.FlashLoanModuleChanged(address(0), newFlashLoanModule);
        vm.prank(dao);
        caliber.setFlashLoanModule(newFlashLoanModule);
        assertEq(caliber.flashLoanModule(), newFlashLoanModule);
    }

    function test_SetPositionStaleThreshold_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setPositionStaleThreshold(2 hours);
    }

    function test_SetPositionStaleThreshold() public {
        uint256 newThreshold = 2 hours;
        vm.expectEmit(true, true, false, false, address(caliber));
        emit ICaliber.PositionStaleThresholdChanged(DEFAULT_CALIBER_POS_STALE_THRESHOLD, newThreshold);
        vm.prank(dao);
        caliber.setPositionStaleThreshold(newThreshold);
        assertEq(caliber.positionStaleThreshold(), newThreshold);
    }

    function test_SetRecoveryMode_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setRecoveryMode(true);
    }

    function test_SetRecoveryMode() public {
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.RecoveryModeChanged(true);
        vm.prank(dao);
        caliber.setRecoveryMode(true);
        assertTrue(caliber.recoveryMode());
    }

    function test_SetTimelockDuration_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setTimelockDuration(2 hours);
    }

    function test_SetTimelockDuration() public {
        uint256 newDuration = 2 hours;
        vm.expectEmit(true, true, false, false, address(caliber));
        emit ICaliber.TimelockDurationChanged(DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK, newDuration);
        vm.prank(dao);
        caliber.setTimelockDuration(newDuration);
        assertEq(caliber.timelockDuration(), newDuration);
    }

    function test_SetMaxPositionIncreaseLossBps_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMaxPositionIncreaseLossBps(1000);
    }

    function test_setMaxPositionIncreaseLossBps() public {
        vm.expectEmit(true, true, true, true, address(caliber));
        emit ICaliber.MaxPositionIncreaseLossBpsChanged(DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS, 1000);
        vm.prank(dao);
        caliber.setMaxPositionIncreaseLossBps(1000);
        assertEq(caliber.maxPositionIncreaseLossBps(), 1000);
    }

    function test_SetMaxPositionDecreaseLossBps_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMaxPositionDecreaseLossBps(1000);
    }

    function test_setMaxPositionDecreaseLossBps() public {
        vm.expectEmit(true, true, true, true, address(caliber));
        emit ICaliber.MaxPositionDecreaseLossBpsChanged(DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS, 1000);
        vm.prank(dao);
        caliber.setMaxPositionDecreaseLossBps(1000);
        assertEq(caliber.maxPositionDecreaseLossBps(), 1000);
    }

    function test_SetMaxSwapLossBps_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMaxSwapLossBps(1000);
    }

    function test_SetMaxSwapLossBps() public {
        vm.expectEmit(true, true, true, true, address(caliber));
        emit ICaliber.MaxSwapLossBpsChanged(DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS, 1000);
        vm.prank(dao);
        caliber.setMaxSwapLossBps(1000);
        assertEq(caliber.maxSwapLossBps(), 1000);
    }
}
