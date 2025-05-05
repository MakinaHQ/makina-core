// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {HubCoreFactory_Integration_Concrete_Test} from "../HubCoreFactory.t.sol";

contract CreateBridgeAdapter_Integration_Concrete_Test is HubCoreFactory_Integration_Concrete_Test {
    function test_CreateBridgeAdapter_RevertWhen_CallerNotMachine() public {
        vm.expectRevert(Errors.NotMachine.selector);
        hubCoreFactory.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, "");
    }
}
