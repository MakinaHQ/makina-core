// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {ICoreRegistry} from "../interfaces/ICoreRegistry.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberFactory} from "../interfaces/ICaliberFactory.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

abstract contract CaliberFactory is MakinaContext, ICaliberFactory {
    /// @custom:storage-location erc7201:makina.storage.CaliberFactory
    struct CaliberFactoryStorage {
        mapping(address caliber => bool isCaliber) _isCaliber;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.CaliberFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CaliberFactoryStorageLocation =
        0x092f83b0a9c245bf0116fc4aaf5564ab048ff47d6596f1c61801f18d9dfbea00;

    function _getCaliberFactoryStorage() internal pure returns (CaliberFactoryStorage storage $) {
        assembly {
            $.slot := CaliberFactoryStorageLocation
        }
    }

    /// @inheritdoc ICaliberFactory
    function isCaliber(address adapter) external view override returns (bool) {
        return _getCaliberFactoryStorage()._isCaliber[adapter];
    }

    /// @dev Internal logic for caliber deployment.
    function _createCaliber(
        ICaliber.CaliberInitParams calldata cParams,
        address accountingToken,
        address machineEndpoint
    ) internal returns (address) {
        address caliber = address(
            new BeaconProxy(
                ICoreRegistry(registry).caliberBeacon(),
                abi.encodeCall(ICaliber.initialize, (cParams, accountingToken, machineEndpoint))
            )
        );

        _getCaliberFactoryStorage()._isCaliber[caliber] = true;

        emit CaliberCreated(caliber, machineEndpoint);

        return caliber;
    }
}
