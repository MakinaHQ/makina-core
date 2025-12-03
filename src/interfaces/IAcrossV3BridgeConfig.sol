// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IBridgeConfig} from "./IBridgeConfig.sol";

interface IAcrossV3BridgeConfig is IBridgeConfig {
    /// @notice Foreign Chain ID => Whether the chain is supported.
    function isForeignChainSupported(uint256 foreignChainId) external view returns (bool);

    /// @notice Sets whether a foreign chain is supported.
    /// @param foreignChainId The foreign chain ID.
    /// @param supported True if the chain is supported, false otherwise.
    function setForeignChainSupported(uint256 foreignChainId, bool supported) external;
}
