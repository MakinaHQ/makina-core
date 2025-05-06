// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {SpokeCoreFactory_Integration_Concrete_Test} from "../SpokeCoreFactory.t.sol";

contract CreateBridgeAdapter_Integration_Concrete_Test is SpokeCoreFactory_Integration_Concrete_Test {
    function test_CreateBridgeAdapter_RevertWhen_CallerNotCaliberMailbox() public {
        vm.expectRevert(Errors.NotCaliberMailbox.selector);
        spokeCoreFactory.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, "");
    }

    function test_CreateBridgeAdapter_RevertWhen_BridgeIdUnsupported() public {
        vm.expectRevert(Errors.InvalidBridgeId.selector);
        vm.prank(address(caliberMailbox));
        spokeCoreFactory.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, "");
    }
}
