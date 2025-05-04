// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";

import {BridgeAdapter_Unit_Concrete_Test} from "../BridgeAdapter.t.sol";

abstract contract AuthorizeInBridgeTransfer_Integration_Concrete_Test is BridgeAdapter_Unit_Concrete_Test {
    function setUp() public virtual override {}

    function test_RevertWhen_CallerNotController() public {
        vm.expectRevert(Errors.NotController.selector);
        bridgeAdapter.authorizeInBridgeTransfer(bytes32(0));
    }

    function test_RevertGiven_MessageAlreadyAuthorized() public {
        bytes32 messageHash = bytes32("12345");

        vm.startPrank(address(controller));

        bridgeAdapter.authorizeInBridgeTransfer(messageHash);

        vm.expectRevert(Errors.MessageAlreadyAuthorized.selector);
        bridgeAdapter.authorizeInBridgeTransfer(messageHash);

        bytes32 messageHash2 = bytes32("67890");
        bridgeAdapter.authorizeInBridgeTransfer(messageHash2);
    }

    function test_AuthorizeInBridgeTransfer() public {
        bytes32 messageHash = bytes32("12345");

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.AuthorizeInBridgeTransfer(messageHash);
        vm.prank(address(controller));
        bridgeAdapter.authorizeInBridgeTransfer(messageHash);
    }
}
