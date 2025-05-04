// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {ICoreRegistry} from "../interfaces/ICoreRegistry.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeAdapterFactory} from "../interfaces/IBridgeAdapterFactory.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

abstract contract BridgeAdapterFactory is MakinaContext, IBridgeAdapterFactory {
    /// @custom:storage-location erc7201:makina.storage.BridgeAdapterFactory
    struct BridgeAdapterFactoryStorage {
        mapping(address adapter => bool isBridgeAdapter) _isBridgeAdapter;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.BridgeAdapterFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BridgeAdapterFactoryStorageLocation =
        0xe2760819b7b5a09214c04233e2d29582188ee1a80d8fe8c82676ab96abf81c00;

    function _getBridgeAdapterFactoryStorage() internal pure returns (BridgeAdapterFactoryStorage storage $) {
        assembly {
            $.slot := BridgeAdapterFactoryStorageLocation
        }
    }

    /// @inheritdoc IBridgeAdapterFactory
    function isBridgeAdapter(address adapter) external view returns (bool) {
        return _getBridgeAdapterFactoryStorage()._isBridgeAdapter[adapter];
    }

    /// @dev Internal logic for bridge adapter deployment.
    function _createBridgeAdapter(address controller, uint16 bridgeId, bytes calldata initData)
        internal
        returns (address)
    {
        address bridgeAdapterBeacon = ICoreRegistry(registry).bridgeAdapterBeacon(bridgeId);
        address bridgeAdapter = address(
            new BeaconProxy(bridgeAdapterBeacon, abi.encodeCall(IBridgeAdapter.initialize, (controller, initData)))
        );
        _getBridgeAdapterFactoryStorage()._isBridgeAdapter[bridgeAdapter] = true;

        emit BridgeAdapterCreated(controller, uint256(bridgeId), bridgeAdapter);

        return bridgeAdapter;
    }
}
