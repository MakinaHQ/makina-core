// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IOracleRegistry} from "./interfaces/IOracleRegistry.sol";

contract OracleRegistry is AccessManagedUpgradeable, IOracleRegistry {
    mapping(address inputToken => mapping(address quoteToken => address priceFeed)) private priceFeeds;

    function initialize(address initialAuthority_) public initializer {
        __AccessManaged_init(initialAuthority_);
    }

    function getPriceFeed(address inputToken, address quoteToken) external view override returns (address priceFeed) {
        priceFeed = priceFeeds[inputToken][quoteToken];
        if (priceFeed == address(0)) {
            revert PriceFeedNotSet(inputToken, quoteToken);
        }
    }

    function setPriceFeed(address inputToken, address quoteToken, address priceFeed) external override restricted {
        priceFeeds[inputToken][quoteToken] = priceFeed;
        emit PriceFeedSet(inputToken, quoteToken, priceFeed);
    }
}
