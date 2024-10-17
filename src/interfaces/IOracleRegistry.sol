// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

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
    error FeedDataNotRegistered();
    error InvalidFeedData();
    error NegativeTokenPrice(address priceFeed);
    error PriceFeedStale(address priceFeed, uint256 updatedAt);

    event FeedStalenessThresholdChange(address indexed feed, uint256 oldThreshold, uint256 newThreshold);
    event TokenFeedDataRegistered(address indexed token, address indexed feed1, address indexed feed2);

    struct TokenFeedData {
        address feed1;
        address feed2;
    }

    /// @notice Feed => Staleness threshold in seconds
    function feedStalenessThreshold(address feed) external view returns (uint256);

    /// @notice Returns the price of one unit of baseToken in terms of quoteToken.
    /// @param baseToken Address of the token for which the price is requested
    /// @param quoteToken Address of the token in which the price is quoted
    /// @return price The price of baseToken denominated in quoteToken (expressed in quoteToken decimals).
    function getPrice(address baseToken, address quoteToken) external view returns (uint256);

    /// @notice Get the price feed data for a given token
    /// @param token Address of the token for which the price feed data is requested
    /// @return feed1 Address of the first price feed
    /// @return feed2 Address of the second price feed
    function getTokenFeedData(address token) external view returns (address, address);

    /// @notice Set the price feed data for a given token
    /// @dev Both feeds, if set, must be Chainlink-interface-compliant.
    /// The combination of feed1 and feed2 must be able to price the token in the reference currency.
    /// If feed2 is set to address(0), the token price in the reference currency is assumed to be returned by feed1.
    /// @param token Address of the token for which the price feed data is set
    /// @param feed1 Address of the first price feed.
    /// @param stalenessThreshold1 Staleness threshold for the first price feed.
    /// @param feed2 Address of the second price feed. Can be set to address(0).
    /// @param stalenessThreshold2 Staleness threshold for the second price feed. Ignored if feed2 is address(0).
    function setTokenFeedData(
        address token,
        address feed1,
        uint256 stalenessThreshold1,
        address feed2,
        uint256 stalenessThreshold2
    ) external;

    /// @notice Set the price staleness threshold for a given feed
    /// @param feed Address of the price feed
    /// @param threshold Value of staleness threshold
    function setFeedStalenessThreshold(address feed, uint256 threshold) external;
}
