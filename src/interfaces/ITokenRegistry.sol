// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice This interface is used to map token addresses from one EVM chain to another.
interface ITokenRegistry {
    event TokenRegistered(address indexed localToken, uint256 indexed evmChainId, address indexed foreignToken);

    /// @notice Local token address => Foreign EVM chain ID => Foreign Token address
    function getForeignToken(address localToken, uint256 foreignEvmChainId) external view returns (address);

    /// @notice Foreign token address => Foreign EVM chain ID => Local Token address
    function getLocalToken(address foreignToken, uint256 foreignEvmChainId) external view returns (address);

    /// @notice Associates a local and a foreign token address.
    /// @param localToken The local token address.
    /// @param foreignEvmChainId The foreign EVM chain ID.
    /// @param foreignToken The foreign token address.
    function setToken(address localToken, uint256 foreignEvmChainId, address foreignToken) external;
}
