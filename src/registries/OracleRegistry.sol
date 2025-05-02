// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {AggregatorV2V3Interface} from "../interfaces/AggregatorV2V3Interface.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";
import {DecimalsUtils} from "../libraries/DecimalsUtils.sol";

contract OracleRegistry is AccessManagedUpgradeable, IOracleRegistry {
    using Math for uint256;

    /// @dev Token => Feed or pair of feeds used to price the token
    mapping(address token => FeedRoute feedRoute) private _feedRoutes;

    /// @inheritdoc IOracleRegistry
    mapping(address feed => uint256 stalenessThreshold) public feedStaleThreshold;

    function initialize(address initialAuthority_) external initializer {
        __AccessManaged_init(initialAuthority_);
    }

    /// @inheritdoc IOracleRegistry
    function isFeedRouteRegistered(address token) external view override returns (bool) {
        return _feedRoutes[token].feed1 != address(0);
    }

    /// @inheritdoc IOracleRegistry
    function getFeedRoute(address token) external view override returns (address, address) {
        FeedRoute memory route = _feedRoutes[token];
        if (route.feed1 == address(0)) {
            revert PriceFeedRouteNotRegistered(token);
        }
        return (route.feed1, route.feed2);
    }

    /// @inheritdoc IOracleRegistry
    function getPrice(address baseToken, address quoteToken) external view override returns (uint256) {
        FeedRoute memory baseFR = _feedRoutes[baseToken];
        FeedRoute memory quoteFR = _feedRoutes[quoteToken];

        if (baseFR.feed1 == address(0)) {
            revert PriceFeedRouteNotRegistered(baseToken);
        }
        if (quoteFR.feed1 == address(0)) {
            revert PriceFeedRouteNotRegistered(quoteToken);
        }

        uint8 baseFRDecimalsSum = _getFeedDecimals(baseFR.feed1) + _getFeedDecimals(baseFR.feed2);
        uint8 quoteFRDecimalsSum = _getFeedDecimals(quoteFR.feed1) + _getFeedDecimals(quoteFR.feed2);
        uint8 quoteTokenDecimals = DecimalsUtils._getDecimals(quoteToken);

        // price = 10^(quoteTokenDecimals + quoteFeedsDecimalsSum - baseFeedsDecimalsSum) *
        //  (baseFeedPrice1 * baseFeedPrice2) / (quoteFeedPrice1 * quoteFeedPrice2)

        if (quoteTokenDecimals + quoteFRDecimalsSum < baseFRDecimalsSum) {
            return _getFeedPrice(baseFR.feed1) * _getFeedPrice(baseFR.feed2)
                / (
                    (10 ** (baseFRDecimalsSum - quoteTokenDecimals - quoteFRDecimalsSum)) * _getFeedPrice(quoteFR.feed1)
                        * _getFeedPrice(quoteFR.feed2)
                );
        }

        return (10 ** (quoteTokenDecimals + quoteFRDecimalsSum - baseFRDecimalsSum)).mulDiv(
            _getFeedPrice(baseFR.feed1) * _getFeedPrice(baseFR.feed2),
            _getFeedPrice(quoteFR.feed1) * _getFeedPrice(quoteFR.feed2)
        );
    }

    /// @inheritdoc IOracleRegistry
    function setFeedRoute(
        address token,
        address feed1,
        uint256 stalenessThreshold1,
        address feed2,
        uint256 stalenessThreshold2
    ) external override restricted {
        if (feed1 == address(0)) {
            revert InvalidFeedRoute();
        }

        uint8 tokenDecimals = DecimalsUtils._getDecimals(token);
        if (tokenDecimals < DecimalsUtils.MIN_DECIMALS || tokenDecimals > DecimalsUtils.MAX_DECIMALS) {
            revert InvalidDecimals();
        }

        _feedRoutes[token] = FeedRoute({feed1: feed1, feed2: feed2});

        feedStaleThreshold[feed1] = stalenessThreshold1;
        if (feed2 != address(0)) {
            feedStaleThreshold[feed2] = stalenessThreshold2;
        }

        emit FeedRouteRegistered(token, feed1, feed2);
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
