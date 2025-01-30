// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IHubDualMailbox} from "src/interfaces/IHubDualMailbox.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {Base_Test} from "test/BaseTest.sol";

contract HubDualMailbox_Unit_Concrete_Test is Base_Test {
    MockPriceFeed private aPriceFeed1;

    MockERC20 internal baseToken;

    IHubDualMailbox internal hubDualMailbox;

    function _setUp() public override {
        baseToken = new MockERC20("baseToken", "BT", 18);

        aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine, caliber) = _deployMachine(address(accountingToken), accountingTokenPosId, bytes32(0));
        hubDualMailbox = IHubDualMailbox(caliber.mailbox());
    }

    function test_hubDualMailbox_getters() public view {
        assertEq(hubDualMailbox.machine(), address(machine));
        assertEq(hubDualMailbox.caliber(), address(caliber));
        assertEq(hubDualMailbox.lastReportedAum(), 0);
        assertEq(hubDualMailbox.lastReportedAumTime(), 0);
    }
}
