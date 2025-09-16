// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract CancelToHubMachine_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_CancelAllowedInstrRootUpdate_RevertWhen_CallerUnauthorized() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.cancelAllowedInstrRootUpdate();
    }

    function test_CancelAllowedInstrRootUpdate_RevertGiven_NoPendingUpdate() public {
        vm.expectRevert(Errors.NoPendingUpdate.selector);
        vm.prank(riskManager);
        caliber.cancelAllowedInstrRootUpdate();
    }

    function test_CancelAllowedInstrRootUpdate_RevertGiven_TimelockExpired() public {
        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.warp(effectiveUpdateTime);

        vm.expectRevert(Errors.NoPendingUpdate.selector);
        vm.prank(riskManager);
        caliber.cancelAllowedInstrRootUpdate();
    }

    function test_CancelAllowedInstrRootUpdate_FromRM() public {
        _test_CancelAllowedInstrRootUpdate(riskManager);
    }

    function test_CancelAllowedInstrRootUpdate_FromSC() public {
        _test_CancelAllowedInstrRootUpdate(securityCouncil);
    }

    function test_CancelAllowedInstrRootUpdate_FromNewGuardian() public {
        address newGuardian = makeAddr("newGuardian");

        vm.prank(dao);
        caliber.addInstrRootGuardian(newGuardian);

        _test_CancelAllowedInstrRootUpdate(newGuardian);
    }

    function _test_CancelAllowedInstrRootUpdate(address caller) internal {
        bytes32 currentRoot = MerkleProofs._getAllowedInstrMerkleRoot();

        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.warp(effectiveUpdateTime - 1);

        vm.expectEmit(true, false, false, false, address(caliber));
        emit ICaliber.NewAllowedInstrRootCancelled(newRoot);
        vm.prank(caller);
        caliber.cancelAllowedInstrRootUpdate();

        assertEq(caliber.pendingAllowedInstrRoot(), bytes32(0));

        vm.warp(effectiveUpdateTime);

        assertEq(caliber.allowedInstrRoot(), currentRoot);
    }
}
