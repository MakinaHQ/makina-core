// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {Base_Test} from "test/BaseTest.sol";

contract OracleRegistry_Unit_Concrete_Test is Base_Test {
    event FeedStaleThresholdChange(address indexed feed, uint256 oldThreshold, uint256 newThreshold);
    event TokenFeedDataRegistered(address indexed token, address indexed feed1, address indexed feed2);

    MockERC20 internal baseToken;
    MockERC20 internal quoteToken;

    MockPriceFeed internal basePriceFeed1;
    MockPriceFeed internal basePriceFeed2;
    MockPriceFeed internal quotePriceFeed1;
    MockPriceFeed internal quotePriceFeed2;

    /// @dev A and B are either base or quote tokens, C and D are intermediate tokens
    /// and E is the reference currency of the oracle registry
    uint256 internal constant PRICE_A_E = 60000;
    uint256 internal constant PRICE_A_C = 24;
    uint256 internal constant PRICE_C_E = 2500;

    uint256 internal constant PRICE_B_E = 600;
    uint256 internal constant PRICE_B_D = 12;
    uint256 internal constant PRICE_D_E = 50;

    uint256 internal constant PRICE_A_B = 100;

    function _setUp() public override {
        baseToken = new MockERC20("Base Token", "BT", 8);
        quoteToken = new MockERC20("Quote Token", "QT", 18);
    }
}
