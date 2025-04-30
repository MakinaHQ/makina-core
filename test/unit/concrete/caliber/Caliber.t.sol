// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";

import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

abstract contract Caliber_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    bytes32 public defaultRoot;

    function setUp() public virtual override {
        Unit_Concrete_Spoke_Test.setUp();

        defaultRoot = keccak256(abi.encodePacked("defaultRoot"));

        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(defaultRoot);
        skip(caliber.timelockDuration() + 1);
    }
}

contract Getters_Setters_Caliber_Unit_Concrete_Test is Caliber_Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(caliber.hubMachineEndpoint(), address(caliberMailbox));
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.flashLoanModule(), address(0));
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
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

    function test_SetPositionStaleThreshold_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(ICaliber.UnauthorizedCaller.selector);
        caliber.setPositionStaleThreshold(2 hours);
    }

    function test_SetPositionStaleThreshold() public {
        uint256 newThreshold = 2 hours;
        vm.expectEmit(true, true, false, false, address(caliber));
        emit ICaliber.PositionStaleThresholdChanged(DEFAULT_CALIBER_POS_STALE_THRESHOLD, newThreshold);
        vm.prank(riskManagerTimelock);
        caliber.setPositionStaleThreshold(newThreshold);
        assertEq(caliber.positionStaleThreshold(), newThreshold);
    }

    function test_SetTimelockDuration_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(ICaliber.UnauthorizedCaller.selector);
        caliber.setTimelockDuration(2 hours);
    }

    function test_SetTimelockDuration() public {
        uint256 newDuration = 2 hours;
        vm.expectEmit(true, true, false, false, address(caliber));
        emit ICaliber.TimelockDurationChanged(DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK, newDuration);
        vm.prank(riskManagerTimelock);
        caliber.setTimelockDuration(newDuration);
        assertEq(caliber.timelockDuration(), newDuration);
    }

    function test_SetMaxPositionIncreaseLossBps_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(ICaliber.UnauthorizedCaller.selector);
        caliber.setMaxPositionIncreaseLossBps(1000);
    }

    function test_setMaxPositionIncreaseLossBps() public {
        vm.expectEmit(true, true, true, true, address(caliber));
        emit ICaliber.MaxPositionIncreaseLossBpsChanged(DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS, 1000);
        vm.prank(riskManagerTimelock);
        caliber.setMaxPositionIncreaseLossBps(1000);
        assertEq(caliber.maxPositionIncreaseLossBps(), 1000);
    }

    function test_SetMaxPositionDecreaseLossBps_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(ICaliber.UnauthorizedCaller.selector);
        caliber.setMaxPositionDecreaseLossBps(1000);
    }

    function test_setMaxPositionDecreaseLossBps() public {
        vm.expectEmit(true, true, true, true, address(caliber));
        emit ICaliber.MaxPositionDecreaseLossBpsChanged(DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS, 1000);
        vm.prank(riskManagerTimelock);
        caliber.setMaxPositionDecreaseLossBps(1000);
        assertEq(caliber.maxPositionDecreaseLossBps(), 1000);
    }

    function test_SetMaxSwapLossBps_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(ICaliber.UnauthorizedCaller.selector);
        caliber.setMaxSwapLossBps(1000);
    }

    function test_SetMaxSwapLossBps() public {
        vm.expectEmit(true, true, true, true, address(caliber));
        emit ICaliber.MaxSwapLossBpsChanged(DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS, 1000);
        vm.prank(riskManagerTimelock);
        caliber.setMaxSwapLossBps(1000);
        assertEq(caliber.maxSwapLossBps(), 1000);
    }

    function test_SetCooldownDuration_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(ICaliber.UnauthorizedCaller.selector);
        caliber.setCooldownDuration(1000);
    }

    function test_SetCooldownDuration() public {
        vm.expectEmit(true, true, false, false, address(caliber));
        emit ICaliber.CooldownDurationChanged(DEFAULT_CALIBER_COOLDOWN_DURATION, 1000);
        vm.prank(riskManagerTimelock);
        caliber.setCooldownDuration(1000);
        assertEq(caliber.cooldownDuration(), 1000);
    }
}
