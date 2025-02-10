// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {Constants} from "src/libraries/Constants.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {Base_Test} from "test/BaseTest.sol";

contract MachineShare_Unit_Concrete_Test is Base_Test {
    MockPriceFeed private aPriceFeed1;

    IMachineShare internal shareToken;

    function _setUp() public override {
        aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine, caliber) = _deployMachine(address(accountingToken), accountingTokenPosId, bytes32(0));
        shareToken = IMachineShare(machine.shareToken());
    }

    function test_hubDualMailbox_getters() public view {
        assertEq(shareToken.machine(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
        assertEq(shareToken.decimals(), Constants.SHARE_TOKEN_DECIMALS);
    }
}
