// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {HubDualMailbox} from "src/mailbox/HubDualMailbox.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract HubDualMailbox_Unit_Concrete_Test is Unit_Concrete_Test {
    function setUp() public override {
        Unit_Concrete_Test.setUp();

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine, caliber) = _deployMachine(address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));
        hubDualMailbox = HubDualMailbox(caliber.mailbox());
    }

    function test_Getters() public view {
        assertEq(hubDualMailbox.machine(), address(machine));
        assertEq(hubDualMailbox.caliber(), address(caliber));
    }
}
