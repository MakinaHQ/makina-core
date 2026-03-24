// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IBridgeConfig} from "./IBridgeConfig.sol";

interface ICctpV2BridgeConfig is IBridgeConfig {
    event ForeignTokenRegistered(address indexed localToken, uint256 indexed evmChainId, address indexed foreignToken);
    event CctpDomainRegistered(uint256 indexed evmChainId, uint32 indexed cctpDomain);

    /// @notice EVM chain ID => CCTP domain
    function getCctpDomain(uint256 evmChainId) external view returns (uint32);

    /// @notice Local token address => Foreign EVM chain ID => Foreign Token address
    function getForeignToken(address localToken, uint256 foreignEvmChainId) external view returns (address);

    /// @notice Associates an EVM chain ID with a CCTP domain in the contract storage.
    /// @param evmChainId The EVM chain ID.
    /// @param cctpDomain The CCTP domain.
    function setCctpDomain(uint256 evmChainId, uint32 cctpDomain) external;

    /// @notice Associates a local token with its foreign counterpart used in CCTP bridging.
    /// @param localToken The local token address.
    /// @param foreignEvmChainId The foreign EVM chain ID.
    /// @param foreignToken The foreign token address.
    function setForeignToken(address localToken, uint256 foreignEvmChainId, address foreignToken) external;
}
