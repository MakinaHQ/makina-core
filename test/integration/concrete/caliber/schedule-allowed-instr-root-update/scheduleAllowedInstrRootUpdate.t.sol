// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract TransferToHubMachine_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotRM() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.scheduleAllowedInstrRootUpdate(bytes32(0));
    }

    function test_RevertGiven_ActivePendingUpdate() public {
        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.startPrank(riskManager);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.expectRevert(Errors.ActiveUpdatePending.selector);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.warp(effectiveUpdateTime);

        newRoot = keccak256(abi.encodePacked("newerRoot"));

        caliber.scheduleAllowedInstrRootUpdate(newRoot);
    }

    function test_RevertWhen_SameRoot() public {
        bytes32 currentRoot = caliber.allowedInstrRoot();

        vm.expectRevert(Errors.SameRoot.selector);
        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(currentRoot);
    }

    function test_ScheduleAllowedInstrRootUpdate() public {
        bytes32 currentRoot = allowedInstrMerkleRoot;

        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.NewAllowedInstrRootScheduled(newRoot, effectiveUpdateTime);
        vm.prank(riskManager);
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

        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.prank(riskManagerTimelock);
        caliber.setTimelockDuration(2 hours);

        assertEq(caliber.pendingTimelockExpiry(), effectiveUpdateTime);

        vm.warp(effectiveUpdateTime);

        assertEq(caliber.allowedInstrRoot(), newRoot);
        assertEq(caliber.pendingAllowedInstrRoot(), bytes32(0));
        assertEq(caliber.pendingTimelockExpiry(), 0);

        newRoot = keccak256(abi.encodePacked("newerRoot"));

        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);
    }
}
