// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";

import {Base_Test} from "test/BaseTest.sol";

contract Caliber_Unit_Concrete_Test is Base_Test {
    function _setUp() public override {
        MockPriceFeed aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(address(accountingToken), address(aPriceFeed1), 0, address(0), 0);

        caliber = _deployCaliber(address(0), address(accountingToken), accountingTokenPosId, bytes32(0));

        // generate merkle tree for instructions involving mock base token and vault
        _generateMerkleData(address(caliber), address(accountingToken), address(0), address(0), 0, address(0), 0);

        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(MerkleProofs._getAllowedInstrMerkleRoot());
        skip(caliber.timelockDuration() + 1);
    }

    function test_caliber_getters() public view {
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

    function test_cannotSetMechanicWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMechanic(address(0x0));
    }

    function test_setMechanic() public {
        address newMechanic = makeAddr("NewMechanic");
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.MechanicChanged(mechanic, newMechanic);
        vm.prank(dao);
        caliber.setMechanic(newMechanic);
        assertEq(caliber.mechanic(), newMechanic);
    }

    function test_cannotSetSecurityCouncilWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setSecurityCouncil(address(0x0));
    }

    function test_setSecurityCouncil() public {
        address newSecurityCouncil = makeAddr("NewSecurityCouncil");
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.SecurityCouncilChanged(securityCouncil, newSecurityCouncil);
        vm.prank(dao);
        caliber.setSecurityCouncil(newSecurityCouncil);
        assertEq(caliber.securityCouncil(), newSecurityCouncil);
    }

    function test_cannotSetPositionStaleThresholdWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setPositionStaleThreshold(2 hours);
    }

    function test_setPositionStaleThreshold() public {
        uint256 newThreshold = 2 hours;
        emit ICaliber.PositionStaleThresholdChanged(DEFAULT_CALIBER_POS_STALE_THRESHOLD, newThreshold);
        vm.prank(dao);
        caliber.setPositionStaleThreshold(newThreshold);
        assertEq(caliber.positionStaleThreshold(), newThreshold);
    }

    function test_cannotSetRecoveryModeWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setRecoveryMode(true);
    }

    function test_setRecoveryMode() public {
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.RecoveryModeChanged(true);
        vm.prank(dao);
        caliber.setRecoveryMode(true);
        assertTrue(caliber.recoveryMode());
    }

    function test_cannotSetTimelockDurationWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setTimelockDuration(2 hours);
    }

    function test_setTimelockDuration() public {
        uint256 newDuration = 2 hours;
        emit ICaliber.TimelockDurationChanged(DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK, newDuration);
        vm.prank(dao);
        caliber.setTimelockDuration(newDuration);
        assertEq(caliber.timelockDuration(), newDuration);
    }

    function test_cannotScheduleRootUpdateWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.scheduleAllowedInstrRootUpdate(bytes32(0));
    }

    function test_scheduleAllowedInstrRootUpdate() public {
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

    function test_timelockDurationChangeDoesNotAffectPendingUpdate() public {
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

    function test_cannotScheduleRootUpdateWithActivePendingUpdate() public {
        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.startPrank(dao);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.expectRevert(ICaliber.ActiveUpdatePending.selector);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.warp(effectiveUpdateTime);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);
    }

    function test_cannotSetMaxMgmtLossBpsWithoutRole() public {
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

    function test_cannotSetMaxSwapLossBpsWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMaxSwapLossBps(1000);
    }

    function test_setMaxSwapLossBps() public {
        vm.expectEmit(true, true, true, true, address(caliber));
        emit ICaliber.MaxSwapLossBpsChanged(DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS, 1000);
        vm.prank(dao);
        caliber.setMaxSwapLossBps(1000);
        assertEq(caliber.maxSwapLossBps(), 1000);
    }
}
