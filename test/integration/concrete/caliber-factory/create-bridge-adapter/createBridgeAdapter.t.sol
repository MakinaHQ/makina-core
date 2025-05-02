// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliberFactory} from "src/interfaces/ICaliberFactory.sol";

import {CaliberFactory_Integration_Concrete_Test} from "../CaliberFactory.t.sol";

contract CreateBridgeAdapter_Integration_Concrete_Test is CaliberFactory_Integration_Concrete_Test {
    function test_CreateBridgeAdapter_RevertWhen_CallerNotCaliberMailbox() public {
        vm.expectRevert(ICaliberFactory.NotCaliberMailbox.selector);
        caliberFactory.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, "");
    }
}
