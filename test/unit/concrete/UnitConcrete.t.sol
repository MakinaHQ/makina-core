// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {Base_Test} from "test/BaseTest.sol";

abstract contract Unit_Concrete_Test is Base_Test {
    MockPriceFeed internal aPriceFeed1;

    function setUp() public virtual override {
        Base_Test.setUp();
        _deployMockTokens();

        aPriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);
    }
}
