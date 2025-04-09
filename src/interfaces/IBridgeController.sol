// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "./IBridgeAdapter.sol";

interface IBridgeController {
    error BridgeAdapterAlreadyExists();
    error BridgeAdapterDoesNotExist();

    event BridgeAdapterCreated(uint256 indexed bridgeId, address indexed adapter);

    /// @notice Bridge ID => Is bridge adapter deployed.
    function isBridgeSupported(IBridgeAdapter.Bridge bridgeId) external view returns (bool);

    /// @notice Returns the address of the bridge adapter for a given bridge ID.
    /// @param bridgeId The ID of the bridge.
    function getBridgeAdapter(IBridgeAdapter.Bridge bridgeId) external view returns (address);

    /// @notice Deploys a new BridgeAdapter instance.
    /// @param bridgeId The ID of the bridge.
    /// @param initData The optional initialization data for the bridge adapter.
    /// @return The address of the deployed BridgeAdapter.
    function createBridgeAdapter(IBridgeAdapter.Bridge bridgeId, bytes calldata initData) external returns (address);
}
