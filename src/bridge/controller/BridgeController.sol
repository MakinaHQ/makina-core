// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {IBaseMakinaRegistry} from "../../interfaces/IBaseMakinaRegistry.sol";
import {IBridgeAdapter} from "../../interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "../../interfaces/IBridgeController.sol";
import {MakinaContext} from "../../utils/MakinaContext.sol";

abstract contract BridgeController is AccessManagedUpgradeable, MakinaContext, IBridgeController {
    /// @custom:storage-location erc7201:makina.storage.BridgeController
    struct BridgeControllerStorage {
        mapping(IBridgeAdapter.Bridge bridgeId => address adapter) _bridgeAdapters;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.BridgeController")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BridgeControllerStorageLocation =
        0x7363d524082cdf545f1ac33985598b84d2470b8b4fbcc6cb47698cc1b2a03500;

    function _getBridgeControllerStorage() private pure returns (BridgeControllerStorage storage $) {
        assembly {
            $.slot := BridgeControllerStorageLocation
        }
    }

    /// @inheritdoc IBridgeController
    function isBridgeSupported(IBridgeAdapter.Bridge bridgeId) external view override returns (bool) {
        return _getBridgeControllerStorage()._bridgeAdapters[bridgeId] != address(0);
    }

    /// @inheritdoc IBridgeController
    function getBridgeAdapter(IBridgeAdapter.Bridge bridgeId) external view override returns (address) {
        BridgeControllerStorage storage $ = _getBridgeControllerStorage();
        if ($._bridgeAdapters[bridgeId] == address(0)) {
            revert BridgeAdapterDoesNotExist();
        }
        return $._bridgeAdapters[bridgeId];
    }

    /// @inheritdoc IBridgeController
    function createBridgeAdapter(IBridgeAdapter.Bridge bridgeId, bytes calldata initData)
        external
        restricted
        returns (address)
    {
        BridgeControllerStorage storage $ = _getBridgeControllerStorage();
        if ($._bridgeAdapters[bridgeId] != address(0)) {
            revert BridgeAdapterAlreadyExists();
        }
        address bridgeAdapterBeacon = IBaseMakinaRegistry(registry).bridgeAdapterBeacon(bridgeId);
        address bridgeAdapter = address(
            new BeaconProxy(bridgeAdapterBeacon, abi.encodeCall(IBridgeAdapter.initialize, (address(this), initData)))
        );
        $._bridgeAdapters[bridgeId] = bridgeAdapter;

        emit BridgeAdapterCreated(uint256(bridgeId), bridgeAdapter);

        return bridgeAdapter;
    }
}
