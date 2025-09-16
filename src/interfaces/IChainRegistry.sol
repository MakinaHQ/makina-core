// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice This interface is used to map EVM chain IDs to Wormhole chain IDs and vice versa.
interface IChainRegistry {
    event ChainIdsRegistered(uint256 indexed evmChainId, uint16 indexed whChainId);

    /// @notice EVM chain ID => Is the chain ID registered
    function isEvmChainIdRegistered(uint256 _evmChainId) external view returns (bool);

    /// @notice Wormhole chain ID => Is the chain ID registered
    function isWhChainIdRegistered(uint16 _whChainId) external view returns (bool);

    /// @notice EVM chain ID => Wormhole chain ID
    function evmToWhChainId(uint256 _evmChainId) external view returns (uint16);

    /// @notice Wormhole chain ID => EVM chain ID
    function whToEvmChainId(uint16 _whChainId) external view returns (uint256);

    /// @notice Associates an EVM chain ID with a Wormhole chain ID in the contract storage.
    /// @param _evmChainId The EVM chain ID.
    /// @param _whChainId The Wormhole chain ID.
    function setChainIds(uint256 _evmChainId, uint16 _whChainId) external;
}
