// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice This interface is used to map token addresses from one evm chain to another.
interface ITokenRegistry {
    event TokenRegistered(address indexed localToken, uint256 indexed evmChainId, address indexed foreignToken);

    /// @notice Local token address => Foreign EVM chain ID => Foreign Token address
    function getForeignToken(address _localToken, uint256 _foreignEvmChainId) external view returns (address);

    /// @notice Foreign token address => Foreign EVM chain ID => Local Token address
    function getLocalToken(address _foreignToken, uint256 _foreignEvmChainId) external view returns (address);

    /// @notice Associates a local and a foreign token addresse.
    /// @param _localToken The local token address.
    /// @param _foreignEvmChainId The foreign EVM chain ID.
    /// @param _foreignToken The foreign token address.
    function setToken(address _localToken, uint256 _foreignEvmChainId, address _foreignToken) external;
}
