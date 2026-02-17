// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IBridgeAdapterFactory {
    event BridgeAdapterCreated(address indexed controller, uint256 indexed bridgeId, address indexed adapter);

    /// @notice Bridge adapter initialization parameters and controller configuration.
    /// @param bridgeId The ID of the bridge for which the adapter is being created.
    /// @param initData The optional initialization data for the bridge adapter.
    /// @param initialMaxBridgeLossBps The initial maximum bridge loss in basis points for this bridge ID and controller.
    struct BridgeAdapterInitParams {
        uint16 bridgeId;
        bytes initData;
        uint256 initialMaxBridgeLossBps;
    }

    /// @notice Address => Whether this is a BridgeAdapter instance deployed by this factory.
    function isBridgeAdapter(address adapter) external view returns (bool);

    /// @notice Deploys a bridge adapter instance.
    /// @param controller The address of the bridge controller for which to deploy the adapter.
    /// @param baParams The bridge adapter initialization parameters and controller configuration.
    /// @return adapter The address of the deployed bridge adapter.
    function createBridgeAdapter(address controller, BridgeAdapterInitParams calldata baParams)
        external
        returns (address adapter);
}
