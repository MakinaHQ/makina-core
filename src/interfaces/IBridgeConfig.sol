// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IBridgeConfig {
    /// @notice Returns whether a bridge transfer route is supported for the associated bridge.
    /// @param inputToken The token being sent from the source chain.
    /// @param foreignChainId The destination chain ID.
    /// @param outputToken The token being received on the destination chain.
    /// @return True if the route is supported, false otherwise.
    function isRouteSupported(address inputToken, uint256 foreignChainId, address outputToken)
        external
        view
        returns (bool);
}
