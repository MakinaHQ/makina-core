// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract CancelToHubMachine_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_CancelAllowedInstrRootUpdate_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.cancelAllowedInstrRootUpdate();
    }

    function test_CancelAllowedInstrRootUpdate_RevertGiven_NoPendingUpdate() public {
        vm.expectRevert(ICaliber.NoPendingUpdate.selector);
        vm.prank(dao);
        caliber.cancelAllowedInstrRootUpdate();
    }

    function test_CancelAllowedInstrRootUpdate_RevertGiven_TimelockExpired() public {
        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.warp(effectiveUpdateTime);

        vm.expectRevert(ICaliber.NoPendingUpdate.selector);
        vm.prank(dao);
        caliber.cancelAllowedInstrRootUpdate();
    }

    function test_CancelAllowedInstrRootUpdate() public {
        bytes32 currentRoot = MerkleProofs._getAllowedInstrMerkleRoot();

        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.warp(effectiveUpdateTime - 1);

        vm.expectEmit(true, false, false, false, address(caliber));
        emit ICaliber.NewAllowedInstrRootCancelled(newRoot);
        vm.prank(dao);
        caliber.cancelAllowedInstrRootUpdate();

        assertEq(caliber.pendingAllowedInstrRoot(), bytes32(0));

        vm.warp(effectiveUpdateTime);

        assertEq(caliber.allowedInstrRoot(), currentRoot);
    }
}
