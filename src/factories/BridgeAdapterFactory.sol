// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {IBaseMakinaRegistry} from "../interfaces/IBaseMakinaRegistry.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeAdapterFactory} from "../interfaces/IBridgeAdapterFactory.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

abstract contract BridgeAdapterFactory is MakinaContext, IBridgeAdapterFactory {
    /// @inheritdoc IBridgeAdapterFactory
    mapping(address adapter => bool isBridgeAdapter) public isBridgeAdapter;

    /// @dev Internal logic for bridge adapter deployment.
    function _createBridgeAdapter(address controller, IBridgeAdapter.Bridge bridgeId, bytes calldata initData)
        internal
        returns (address)
    {
        address bridgeAdapterBeacon = IBaseMakinaRegistry(registry).bridgeAdapterBeacon(bridgeId);
        address bridgeAdapter = address(
            new BeaconProxy(bridgeAdapterBeacon, abi.encodeCall(IBridgeAdapter.initialize, (controller, initData)))
        );
        isBridgeAdapter[bridgeAdapter] = true;

        emit BridgeAdapterCreated(controller, uint256(bridgeId), bridgeAdapter);

        return bridgeAdapter;
    }
}
