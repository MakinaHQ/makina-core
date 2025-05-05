// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IBridgeAdapterFactory {
    event BridgeAdapterCreated(address indexed controller, uint256 indexed bridgeId, address indexed adapter);

    /// @notice Address => Whether this is a BridgeAdapter instance deployed by this factory.
    function isBridgeAdapter(address adapter) external view returns (bool);

    /// @notice Deploys a bridge adapter instance.
    /// @param bridgeId The ID of the bridge for which the adapter is being created.
    /// @param initData The optional initialization data for the bridge adapter.
    /// @return adapter The address of the deployed bridge adapter.
    function createBridgeAdapter(uint16 bridgeId, bytes calldata initData) external returns (address adapter);
}
