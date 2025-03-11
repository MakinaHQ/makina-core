// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @notice This interface is used to map EVM chain IDs to Wormhole chain IDs and vice versa.
interface IChainRegistry {
    error ChainIdNotRegistered();
    error ZeroChainId();

    /// @dev EVM chain ID => Wormhole chain ID
    function evmToWhChainId(uint256 _evmChainId) external view returns (uint16);

    /// @dev Wormhole chain ID => EVM chain ID
    function whToEvmChainId(uint16 _whChainId) external view returns (uint256);

    /// @notice Associates an EVM chain ID with a Wormhole chain ID in the contract storage.
    /// @param _evmChainId The EVM chain ID.
    /// @param _whChainId The Wormhole chain ID.
    function setChainIds(uint256 _evmChainId, uint16 _whChainId) external;
}
