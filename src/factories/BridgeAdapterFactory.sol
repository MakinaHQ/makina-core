// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {Create3Factory} from "./Create3Factory.sol";
import {ICoreRegistry} from "../interfaces/ICoreRegistry.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeAdapterFactory} from "../interfaces/IBridgeAdapterFactory.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";
import {Errors} from "../libraries/Errors.sol";

abstract contract BridgeAdapterFactory is Create3Factory, MakinaContext, IBridgeAdapterFactory {
    // keccak256("makina.salt.BridgeAdapter")
    bytes32 private constant BridgeAdapterSaltDomain =
        0xabde28237b51fa1256b2a1c49d990c305c6556881cd721a86b97a8ef9073992c;

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

    /// @dev Internal logic for bridge adapter deployment via create3.
    function _createBridgeAdapter(address controller, uint16 bridgeId, bytes calldata initData, bytes32 salt)
        internal
        returns (address)
    {
        address beacon = ICoreRegistry(registry).bridgeAdapterBeacon(bridgeId);
        if (beacon == address(0)) {
            revert Errors.InvalidBridgeId();
        }

        bytes32 saltDomain = keccak256(abi.encode(BridgeAdapterSaltDomain, bridgeId));
        bytes memory initCD = abi.encodeCall(IBridgeAdapter.initialize, (controller, initData));
        bytes memory bytecode = abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(beacon, initCD));

        address bridgeAdapter = _create3(saltDomain, salt, bytecode);

        _getBridgeAdapterFactoryStorage()._isBridgeAdapter[bridgeAdapter] = true;

        emit BridgeAdapterCreated(controller, uint256(bridgeId), bridgeAdapter);

        return bridgeAdapter;
    }
}
