// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracleRegistry} from "./interfaces/IOracleRegistry.sol";
import {AggregatorV2V3Interface} from "./interfaces/AggregatorV2V3Interface.sol";

contract OracleRegistry is AccessManagedUpgradeable, IOracleRegistry {
    using Math for uint256;

    /// @dev Token => Feed or pair of feeds used to price the token
    mapping(address token => TokenFeedData feedData) private _tokenFeedData;

    /// @inheritdoc IOracleRegistry
    mapping(address feed => uint256 stalenessThreshold) public feedStaleThreshold;

    function initialize(address initialAuthority_) public initializer {
        __AccessManaged_init(initialAuthority_);
    }

    /// @inheritdoc IOracleRegistry
    function getPrice(address baseToken, address quoteToken) external view override returns (uint256) {
        TokenFeedData memory baseFD = _tokenFeedData[baseToken];
        TokenFeedData memory quoteFD = _tokenFeedData[quoteToken];

        if (baseFD.feed1 == address(0) || quoteFD.feed1 == address(0)) {
            revert FeedDataNotRegistered();
        }

        uint8 baseFDDecimalsSum = _getFeedDecimals(baseFD.feed1) + _getFeedDecimals(baseFD.feed2);
        uint8 quoteFDDecimalsSum = _getFeedDecimals(quoteFD.feed1) + _getFeedDecimals(quoteFD.feed2);
        uint8 quoteTokenDecimals = IERC20Metadata(quoteToken).decimals();

        // price = 10^(quoteTokenDecimals + quoteFeedsDecimalsSum - baseFeedsDecimalsSum) *
        //  (baseFeedPrice1 * baseFeedPrice2) / (quoteFeedPrice1 * quoteFeedPrice2)

        if (quoteTokenDecimals + quoteFDDecimalsSum < baseFDDecimalsSum) {
            return _getFeedPrice(baseFD.feed1) * _getFeedPrice(baseFD.feed2)
                / (
                    (10 ** (baseFDDecimalsSum - quoteTokenDecimals - quoteFDDecimalsSum)) * _getFeedPrice(quoteFD.feed1)
                        * _getFeedPrice(quoteFD.feed2)
                );
        }

        return (10 ** (quoteTokenDecimals + quoteFDDecimalsSum - baseFDDecimalsSum)).mulDiv(
            _getFeedPrice(baseFD.feed1) * _getFeedPrice(baseFD.feed2),
            _getFeedPrice(quoteFD.feed1) * _getFeedPrice(quoteFD.feed2)
        );
    }

    /// @inheritdoc IOracleRegistry
    function getTokenFeedData(address token) external view override returns (address, address) {
        TokenFeedData memory data = _tokenFeedData[token];
        if (data.feed1 == address(0)) {
            revert FeedDataNotRegistered();
        }
        return (data.feed1, data.feed2);
    }

    /// @inheritdoc IOracleRegistry
    function setTokenFeedData(
        address token,
        address feed1,
        uint256 stalenessThreshold1,
        address feed2,
        uint256 stalenessThreshold2
    ) external override restricted {
        if (feed1 == address(0)) {
            revert InvalidFeedData();
        }
        _tokenFeedData[token] = TokenFeedData({feed1: feed1, feed2: feed2});

        feedStaleThreshold[feed1] = stalenessThreshold1;
        if (feed2 != address(0)) {
            feedStaleThreshold[feed2] = stalenessThreshold2;
        }

        emit TokenFeedDataRegistered(token, feed1, feed2);
    }

    /// @inheritdoc IOracleRegistry
    function setFeedStaleThreshold(address feed, uint256 newThreshold) external restricted {
        emit FeedStaleThresholdChange(feed, feedStaleThreshold[feed], newThreshold);
        // zero is allowed in order to disable a feed
        feedStaleThreshold[feed] = newThreshold;
    }

    /// @dev Returns the last price of the feed.
    /// @dev Reverts if the feed is stale or the price is negative.
    function _getFeedPrice(address feed) private view returns (uint256) {
        if (feed == address(0)) {
            return 1;
        }
        (, int256 answer,, uint256 updatedAt,) = AggregatorV2V3Interface(feed).latestRoundData();
        if (answer < 0) {
            revert NegativeTokenPrice(feed);
        }
        if (block.timestamp - updatedAt >= feedStaleThreshold[feed]) {
            revert PriceFeedStale(feed, updatedAt);
        }
        return uint256(answer);
    }

    /// @dev Returns the number of decimals of the feed.
    /// @dev Returns 0 if the feed is not set.
    function _getFeedDecimals(address feed) private view returns (uint8) {
        if (feed == address(0)) {
            return 0;
        }
        return AggregatorV2V3Interface(feed).decimals();
    }
}
