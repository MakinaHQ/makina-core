// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IBridgeConfig} from "./IBridgeConfig.sol";

interface ILayerZeroV2Config is IBridgeConfig {
    event ForeignTokenRegistered(address indexed localToken, uint256 indexed evmChainId, address indexed foreignToken);
    event LzChainIdRegistered(uint256 indexed evmChainId, uint32 indexed lzChainId);
    event OftRegistered(address indexed oft, address indexed token);

    /// @notice EVM chain ID => LayerZero endpoint ID
    function evmToLzChainId(uint256 evmChainId) external view returns (uint32);

    /// @notice LayerZero endpoint ID => EVM chain ID
    function lzToEvmChainId(uint32 lzChainId) external view returns (uint256);

    /// @notice Token address => LayerZero OFT address
    function tokenToOft(address token) external view returns (address);

    /// @notice Local token address => Foreign EVM chain ID => Foreign Token address
    function getForeignToken(address localToken, uint256 foreignEvmChainId) external view returns (address);

    /// @notice Associates an EVM chain ID with a LayerZero endpoint ID in the contract storage.
    /// @param evmChainId The EVM chain ID.
    /// @param lzChainId The Wormhole chain ID.
    function setLzChainId(uint256 evmChainId, uint32 lzChainId) external;

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
