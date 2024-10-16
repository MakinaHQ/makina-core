// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Test.sol";

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracleRegistry} from "./interfaces/IOracleRegistry.sol";
import {AggregatorV2V3Interface} from "./interfaces/AggregatorV2V3Interface.sol";

contract OracleRegistry is AccessManagedUpgradeable, IOracleRegistry {
    using Math for uint256;

    /// @inheritdoc IOracleRegistry
    mapping(address feed => uint256 stalenessThreshold) public feedStalenessThreshold;
    /// @inheritdoc IOracleRegistry
    uint256 public defaultFeedStalenessThreshold;

    mapping(address token => TokenFeedData feedData) private tokenFeedData;

    function initialize(uint256 defaultFeedStalenessThreshold_, address initialAuthority_) public initializer {
        defaultFeedStalenessThreshold = defaultFeedStalenessThreshold_;
        __AccessManaged_init(initialAuthority_);
    }

    /// @inheritdoc IOracleRegistry
    function getPrice(address baseToken, address quoteToken) external view override returns (uint256) {
        TokenFeedData memory baseFD = tokenFeedData[baseToken];
        TokenFeedData memory quoteFD = tokenFeedData[quoteToken];

        if (baseFD.feed1 == address(0) || quoteFD.feed1 == address(0)) {
            revert FeedDataNotRegistered();
        }

        return (10 ** IERC20Metadata(quoteToken).decimals()).mulDiv(
            (10 ** quoteFD.decimalsSum) * _getFeedPrice(baseFD.feed1) * _getFeedPrice(baseFD.feed2),
            (10 ** baseFD.decimalsSum) * _getFeedPrice(quoteFD.feed1) * _getFeedPrice(quoteFD.feed2)
        );
    }

    /// @inheritdoc IOracleRegistry
    function getTokenFeedData(address token) external view override returns (address, address, uint256) {
        TokenFeedData memory data = tokenFeedData[token];
        if (data.feed1 == address(0)) {
            revert FeedDataNotRegistered();
        }
        return (data.feed1, data.feed2, data.decimalsSum);
    }

    /// @inheritdoc IOracleRegistry
    function setTokenFeedData(address token, address feed1, address feed2) external override restricted {
        if (feed1 == address(0)) {
            revert InvalidFeedData();
        }
        tokenFeedData[token] =
            TokenFeedData({feed1: feed1, feed2: feed2, decimalsSum: _getFeedDecimals(feed1) + _getFeedDecimals(feed2)});
        if (feedStalenessThreshold[feed1] == 0) {
            feedStalenessThreshold[feed1] = defaultFeedStalenessThreshold;
        }
        if (feedStalenessThreshold[feed2] == 0) {
            feedStalenessThreshold[feed2] = defaultFeedStalenessThreshold;
        }
        emit TokenFeedDataRegistered(token, feed1, feed2);
    }

    /// @inheritdoc IOracleRegistry
    function setDefaultStalenessThreshold(uint256 newThreshold) external override restricted {
        emit DefaultStalenessThresholdChange(defaultFeedStalenessThreshold, newThreshold);
        defaultFeedStalenessThreshold = newThreshold;
    }

    /// @inheritdoc IOracleRegistry
    function setFeedStalenessThreshold(address feed, uint256 newThreshold) external restricted {
        emit FeedStalenessThresholdChange(feed, feedStalenessThreshold[feed], newThreshold);
        feedStalenessThreshold[feed] = newThreshold;
    }

    function _getFeedPrice(address feed) private view returns (uint256) {
        if (feed == address(0)) {
            return 1;
        }
        (, int256 answer,, uint256 updatedAt,) = AggregatorV2V3Interface(feed).latestRoundData();
        if (answer < 0) {
            revert NegativeTokenPrice(feed);
        }
        if (block.timestamp - updatedAt > feedStalenessThreshold[feed]) {
            revert PriceFeedStale(feed, updatedAt);
        }
        return uint256(answer);
    }

    function _getFeedDecimals(address feed) private view returns (uint256) {
        if (feed == address(0)) {
            return 0;
        }
        return AggregatorV2V3Interface(feed).decimals();
    }
}
