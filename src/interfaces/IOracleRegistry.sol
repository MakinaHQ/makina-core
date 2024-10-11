// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

interface IOracleRegistry {
    error PriceFeedNotSet(address inputToken, address quoteToken);

    event PriceFeedSet(address indexed inputToken, address indexed quoteToken, address priceFeed);

    /// @notice Get the price feed for a given token pair
    /// @param inputToken Address of the token for which the price is requested
    /// @param quoteToken Address of the token in which the price is quoted
    /// @return priceFeed Address of the price feed
    function getPriceFeed(address inputToken, address quoteToken) external view returns (address);

    /// @notice Register a price feed for a given token pair
    /// @param inputToken Address of the token for which the price is requested
    /// @param quoteToken Address of the token in which the price is quoted
    /// @param priceFeed .
    function setPriceFeed(address inputToken, address quoteToken, address priceFeed) external;
}
