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
        assertFalse(spokeSnapshotConsumer.isCreWorkflowNameAuthorized(bytes10(0)));
        assertEq(spokeSnapshotConsumer.creWorkflowAuthor(), DEFAULT_CRE_WORKFLOW_AUTHOR);
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

    function test_RemoveCreWorkflowId_RevertGiven_NoMoreWorkflowIdAuthorizedNorAuthor() public {
        vm.startPrank(dao);

        bytes32 workflowId = bytes32("Id");
        spokeSnapshotConsumer.addCreWorkflowId(workflowId);

        spokeSnapshotConsumer.setCreWorkflowAuthor(address(0));

        vm.expectRevert(Errors.CreWorkflowAuthorRequired.selector);
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

    function test_AddCreWorkflowName_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeSnapshotConsumer.addCreWorkflowName(bytes10(0));
    }

    function test_AddCreWorkflowName_RevertWhen_NameAlreadyAuthorized() public {
        bytes10 workflowName = bytes10("Name");
        vm.prank(dao);
        spokeSnapshotConsumer.addCreWorkflowName(workflowName);

        vm.expectRevert(Errors.CreWorkflowNameAlreadyAuthorized.selector);
        vm.prank(dao);
        spokeSnapshotConsumer.addCreWorkflowName(workflowName);
    }

    function test_AddCreWorkflowName() public {
        bytes10 newWorkflowName = bytes10("Name");
        vm.expectEmit(true, false, false, false, address(spokeSnapshotConsumer));
        emit ISpokeSnapshotConsumer.CreWorkflowNameAdded(newWorkflowName);
        vm.prank(dao);
        spokeSnapshotConsumer.addCreWorkflowName(newWorkflowName);
        assertTrue(spokeSnapshotConsumer.isCreWorkflowNameAuthorized(newWorkflowName));
    }

    function test_RemoveCreWorkflowName_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeSnapshotConsumer.removeCreWorkflowName(bytes10(0));
    }

    function test_RemoveCreWorkflowName_RevertWhen_NameNotAuthorized() public {
        bytes10 workflowName = bytes10("Name");
        vm.expectRevert(Errors.CreWorkflowNameNotAuthorized.selector);
        vm.prank(dao);
        spokeSnapshotConsumer.removeCreWorkflowName(workflowName);
    }

    function test_RemoveCreWorkflowName() public {
        vm.startPrank(dao);

        bytes10 workflowName = bytes10("Name");
        spokeSnapshotConsumer.addCreWorkflowName(workflowName);
        vm.expectEmit(true, false, false, false, address(spokeSnapshotConsumer));
        emit ISpokeSnapshotConsumer.CreWorkflowNameRemoved(workflowName);
        spokeSnapshotConsumer.removeCreWorkflowName(workflowName);
        assertFalse(spokeSnapshotConsumer.isCreWorkflowNameAuthorized(workflowName));
    }

    function test_SetCreWorkflowAuthor_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeSnapshotConsumer.setCreWorkflowAuthor(address(0));
    }

    function test_SetCreWorkflowAuthor_RevertGiven_ZeroAddress_NoWorkflowIdAuthorized() public {
        vm.expectRevert(Errors.CreWorkflowAuthorRequired.selector);
        vm.prank(dao);
        spokeSnapshotConsumer.setCreWorkflowAuthor(address(0));
    }

    function test_SetCreWorkflowAuthor() public {
        vm.startPrank(dao);

        address newWorkflowAuthor = makeAddr("author");
        vm.expectEmit(true, true, false, false, address(spokeSnapshotConsumer));
        emit ISpokeSnapshotConsumer.CreWorkflowAuthorChanged(DEFAULT_CRE_WORKFLOW_AUTHOR, newWorkflowAuthor);
        spokeSnapshotConsumer.setCreWorkflowAuthor(newWorkflowAuthor);
        assertEq(spokeSnapshotConsumer.creWorkflowAuthor(), newWorkflowAuthor);

        spokeSnapshotConsumer.addCreWorkflowId(bytes32("Id"));
        spokeSnapshotConsumer.setCreWorkflowAuthor(address(0));
        assertEq(spokeSnapshotConsumer.creWorkflowAuthor(), address(0));
    }
}
