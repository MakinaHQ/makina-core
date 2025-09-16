// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice An aggregator of Chainlink price feeds that prices tokens in a reference currency (e.g., USD) using up to two feeds.
/// If a direct feed between a base token and the reference currency does not exists, it combines two feeds to compute the price.
///
/// Example:
/// To price Token A in Token B:
/// - If a feed for Token A -> Reference Currency exists, the registry uses that feed.
/// - If Token B lacks a direct feed to the Reference Currency, but feeds for Token B -> Intermediate Token and
///   Intermediate Token -> Reference Currency exist, the registry combines these feeds to derive the price.
/// - Finally, the price Token A -> Token B is calculated using both tokens individual prices in the reference currency.
///
interface IOracleRegistry {
    event FeedRouteRegistered(address indexed token, address indexed feed1, address indexed feed2);
    event FeedStaleThresholdChanged(address indexed feed, uint256 oldThreshold, uint256 newThreshold);

    struct FeedRoute {
        address feed1;
        address feed2;
    }

    /// @notice Feed => Staleness threshold in seconds
    function getFeedStaleThreshold(address feed) external view returns (uint256);

    /// @notice Token => Is feed route registered for the token
    function isFeedRouteRegistered(address token) external view returns (bool);

    /// @notice Gets the price feed route for a given token.
    /// @param token The address of the token for which the price feed route is requested.
    /// @return feed1 The address of the first price feed.
    /// @return feed2 The address of the optional second price feed.
    function getFeedRoute(address token) external view returns (address, address);

    /// @notice Returns the price of one unit of baseToken in terms of quoteToken.
    /// @param baseToken The address of the token for which the price is requested.
    /// @param quoteToken The address of the token in which the price is quoted.
    /// @return price The price of baseToken denominated in quoteToken (expressed in quoteToken decimals).
    function getPrice(address baseToken, address quoteToken) external view returns (uint256);

    /// @notice Sets the price feed route for a given token.
    /// @dev Both feeds, if set, must be Chainlink-interface-compliant.
    /// The combination of feed1 and feed2 must be able to price the token in the reference currency.
    /// If feed2 is set to address(0), the token price in the reference currency is assumed to be returned by feed1.
    /// @param token The address of the token for which the price feed route is set.
    /// @param feed1 The address of the first price feed.
    /// @param stalenessThreshold1 The staleness threshold for the first price feed.
    /// @param feed2 The address of the second price feed. Can be set to address(0).
    /// @param stalenessThreshold2 The staleness threshold for the second price feed. Ignored if feed2 is address(0).
    function setFeedRoute(
        address token,
        address feed1,
        uint256 stalenessThreshold1,
        address feed2,
        uint256 stalenessThreshold2
    ) external;

    /// @notice Sets the price staleness threshold for a given feed.
    /// @param feed The address of the price feed.
    /// @param threshold The value of staleness threshold.
    function setFeedStaleThreshold(address feed, uint256 threshold) external;
}
