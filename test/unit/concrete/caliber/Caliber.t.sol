// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract Caliber_Unit_Concrete_Test is Unit_Concrete_Test {
    function setUp() public override {
        Unit_Concrete_Test.setUp();

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(address(accountingToken), address(aPriceFeed1), 0, address(0), 0);

        caliber = _deployCaliber(address(0), address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));

        // generate merkle tree for instructions involving mock base token and vault
        _generateMerkleData(address(caliber), address(accountingToken), address(0), address(0), 0, address(0), 0);

        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(MerkleProofs._getAllowedInstrMerkleRoot());
        skip(caliber.timelockDuration() + 1);
    }

    function test_Getters() public view {
        assertNotEq(caliber.mailbox(), address(0));
        assertEq(caliber.mechanic(), mechanic);
        assertEq(caliber.securityCouncil(), securityCouncil);
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.lastReportedAUM(), 0);
        assertEq(caliber.lastReportedAUMTime(), 0);
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
        assertEq(caliber.recoveryMode(), false);
        assertEq(caliber.allowedInstrRoot(), MerkleProofs._getAllowedInstrMerkleRoot());
        assertEq(caliber.timelockDuration(), 1 hours);
        assertEq(caliber.pendingAllowedInstrRoot(), bytes32(0));
        assertEq(caliber.pendingTimelockExpiry(), 0);
        assertEq(caliber.maxMgmtLossBps(), DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS);
        assertEq(caliber.maxSwapLossBps(), DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS);
        assertEq(caliber.isBaseToken(address(accountingToken)), true);
        assertEq(caliber.getPositionsLength(), 1);
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

    function test_SetPositionStaleThreshold_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setPositionStaleThreshold(2 hours);
    }

    function test_SetPositionStaleThreshold() public {
        uint256 newThreshold = 2 hours;
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
        emit ICaliber.TimelockDurationChanged(DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK, newDuration);
        vm.prank(dao);
        caliber.setTimelockDuration(newDuration);
        assertEq(caliber.timelockDuration(), newDuration);
    }

    function test_ScheduleAllowedInstrRootUpdate_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.scheduleAllowedInstrRootUpdate(bytes32(0));
    }

    function test_ScheduleAllowedInstrRootUpdate() public {
        bytes32 currentRoot = MerkleProofs._getAllowedInstrMerkleRoot();

        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.NewAllowedInstrRootScheduled(newRoot, effectiveUpdateTime);
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        assertEq(caliber.allowedInstrRoot(), currentRoot);
        assertEq(caliber.pendingAllowedInstrRoot(), newRoot);
        assertEq(caliber.pendingTimelockExpiry(), effectiveUpdateTime);

        vm.warp(effectiveUpdateTime);

        assertEq(caliber.allowedInstrRoot(), newRoot);
        assertEq(caliber.pendingAllowedInstrRoot(), bytes32(0));
        assertEq(caliber.pendingTimelockExpiry(), 0);
    }

    function test_SetTimelockDuration_DoesNotAffectPendingRootUpdate() public {
        assertEq(caliber.timelockDuration(), 1 hours);

        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.startPrank(dao);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);
        caliber.setTimelockDuration(2 hours);

        assertEq(caliber.pendingTimelockExpiry(), effectiveUpdateTime);

        vm.warp(effectiveUpdateTime);

        assertEq(caliber.allowedInstrRoot(), newRoot);
        assertEq(caliber.pendingAllowedInstrRoot(), bytes32(0));
        assertEq(caliber.pendingTimelockExpiry(), 0);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);
    }

    function test_ScheduleRootUpdate_RevertGiven_ActivePendingUpdate() public {
        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.startPrank(dao);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.expectRevert(ICaliber.ActiveUpdatePending.selector);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.warp(effectiveUpdateTime);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);
    }

    function test_SetMaxMgmtLossBps_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMaxMgmtLossBps(1000);
    }

    function test_setMaxMgmtLossBps() public {
        vm.expectEmit(true, true, true, true, address(caliber));
        emit ICaliber.MaxMgmtLossBpsChanged(DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS, 1000);
        vm.prank(dao);
        caliber.setMaxMgmtLossBps(1000);
        assertEq(caliber.maxMgmtLossBps(), 1000);
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
