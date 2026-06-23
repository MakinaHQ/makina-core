// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

import {ICreReceiver} from "src/interfaces/ICreReceiver.sol";
import {ISpokeSnapshotConsumer} from "src/interfaces/ISpokeSnapshotConsumer.sol";
import {Errors} from "src/libraries/Errors.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

abstract contract SpokeSnapshotConsumer_Unit_Concrete_Test is Unit_Concrete_Test {
    ISpokeSnapshotConsumer internal spokeSnapshotConsumer;

    function setUp() public virtual override {}

    function test_SpokeSnapshotConsumerGetters() public view {
        assertFalse(spokeSnapshotConsumer.isCreWorkflowIdAuthorized(bytes32(0)));
        assertTrue(spokeSnapshotConsumer.supportsInterface(type(ICreReceiver).interfaceId));
        assertTrue(spokeSnapshotConsumer.supportsInterface(type(IERC165).interfaceId));
    }

    function test_AddCreWorkflowId_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeSnapshotConsumer.addCreWorkflowId(bytes32(0));
    }

    function test_AddCreWorkflowId_RevertWhen_IdAlreadyAuthorized() public {
        bytes32 workflowId = bytes32("Id");
        vm.prank(dao);
        spokeSnapshotConsumer.addCreWorkflowId(workflowId);

        vm.expectRevert(Errors.CreWorkflowIdAlreadyAuthorized.selector);
        vm.prank(dao);
        spokeSnapshotConsumer.addCreWorkflowId(workflowId);
    }

    function test_AddCreWorkflowId() public {
        bytes32 newWorkflowId = bytes32("Id");
        vm.expectEmit(true, false, false, false, address(spokeSnapshotConsumer));
        emit ISpokeSnapshotConsumer.CreWorkflowIdAdded(newWorkflowId);
        vm.prank(dao);
        spokeSnapshotConsumer.addCreWorkflowId(newWorkflowId);
        assertTrue(spokeSnapshotConsumer.isCreWorkflowIdAuthorized(newWorkflowId));
    }

    function test_RemoveCreWorkflowId_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeSnapshotConsumer.removeCreWorkflowId(bytes32(0));
    }

    function test_RemoveCreWorkflowId_RevertWhen_IdNotAuthorized() public {
        bytes32 workflowId = bytes32("Id");
        vm.expectRevert(Errors.CreWorkflowIdNotAuthorized.selector);
        vm.prank(dao);
        spokeSnapshotConsumer.removeCreWorkflowId(workflowId);
    }

    function test_RemoveCreWorkflowId() public {
        vm.startPrank(dao);

        bytes32 workflowId = bytes32("Id");
        spokeSnapshotConsumer.addCreWorkflowId(workflowId);
        vm.expectEmit(true, false, false, false, address(spokeSnapshotConsumer));
        emit ISpokeSnapshotConsumer.CreWorkflowIdRemoved(workflowId);
        spokeSnapshotConsumer.removeCreWorkflowId(workflowId);
        assertFalse(spokeSnapshotConsumer.isCreWorkflowIdAuthorized(workflowId));
    }
}
