// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBridgeConfig} from "./IBridgeConfig.sol";

interface ILayerZeroV2BridgeConfig is IBridgeConfig {
    event ForeignTokenRegistered(address indexed localToken, uint256 indexed evmChainId, address indexed foreignToken);
    event LzEndpointIdRegistered(uint256 indexed evmChainId, uint32 indexed lzEndpointId);
    event OftRegistered(address indexed oft, address indexed token);

    /// @notice EVM chain ID => LayerZero endpoint ID
    function getLzEndpointId(uint256 evmChainId) external view returns (uint32);

    /// @notice Local token address => LayerZero OFT address
    function getOft(address localToken) external view returns (address);

    /// @notice Local token address => Foreign EVM chain ID => Foreign Token address
    function getForeignToken(address localToken, uint256 foreignEvmChainId) external view returns (address);

    /// @notice Associates an EVM chain ID with a LayerZero endpoint ID in the contract storage.
    /// @param evmChainId The EVM chain ID.
    /// @param lzEndpointId The LayerZero endpoint ID.
    function setLzEndpointId(uint256 evmChainId, uint32 lzEndpointId) external;

    /// @notice Registers a LayerZero OFT for its associated token.
    /// @dev Assumes that an OFT's associated token is immutable.
    /// @dev Overwrites any previously registered OFT for the provided OFT's associated token.
    /// @param oft The address of the LayerZero OFT.
    function setOft(address oft) external;

    /// @notice Associates a local token with its foreign counterpart used in LayerZero bridging.
    /// @param localToken The local token address.
    /// @param foreignEvmChainId The foreign EVM chain ID.
    /// @param foreignToken The foreign token address.
    function setForeignToken(address localToken, uint256 foreignEvmChainId, address foreignToken) external;
}
