// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {BridgeAdapterFactory} from "./BridgeAdapterFactory.sol";
import {IBridgeAdapterFactory} from "../interfaces/IBridgeAdapterFactory.sol";
import {ICaliberFactory} from "../interfaces/ICaliberFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox} from "../interfaces/ICaliberMailbox.sol";
import {IMakinaGovernable} from "../interfaces/IMakinaGovernable.sol";
import {ISpokeRegistry} from "../interfaces/ISpokeRegistry.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

contract CaliberFactory is AccessManagedUpgradeable, BridgeAdapterFactory, ICaliberFactory {
    /// @custom:storage-location erc7201:makina.storage.CaliberFactory
    struct CaliberFactoryStorage {
        mapping(address caliber => bool isCaliber) _isCaliber;
        mapping(address caliber => bool isCaliber) _isCaliberMailbox;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.CaliberFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CaliberFactoryStorageLocation =
        0x092f83b0a9c245bf0116fc4aaf5564ab048ff47d6596f1c61801f18d9dfbea00;

    function _getCaliberFactoryStorage() internal pure returns (CaliberFactoryStorage storage $) {
        assembly {
            $.slot := CaliberFactoryStorageLocation
        }
    }

    constructor(address _registry) MakinaContext(_registry) {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc ICaliberFactory
    function isCaliber(address caliber) external view override returns (bool) {
        return _getCaliberFactoryStorage()._isCaliber[caliber];
    }

    /// @inheritdoc ICaliberFactory
    function isCaliberMailbox(address caliberMailbox) external view override returns (bool) {
        return _getCaliberFactoryStorage()._isCaliberMailbox[caliberMailbox];
    }

    /// @inheritdoc ICaliberFactory
    function createCaliber(
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address accountingToken,
        address hubMachine
    ) external override restricted returns (address) {
        CaliberFactoryStorage storage $ = _getCaliberFactoryStorage();
        address mailbox = address(
            new BeaconProxy(
                ISpokeRegistry(registry).caliberMailboxBeacon(),
                abi.encodeCall(ICaliberMailbox.initialize, (mgParams, hubMachine))
            )
        );
        address caliber = address(
            new BeaconProxy(
                ISpokeRegistry(registry).caliberBeacon(),
                abi.encodeCall(ICaliber.initialize, (cParams, accountingToken, mailbox))
            )
        );
        ICaliberMailbox(mailbox).setCaliber(caliber);
        $._isCaliber[caliber] = true;
        $._isCaliberMailbox[mailbox] = true;
        emit SpokeCaliberCreated(hubMachine, caliber, mailbox);
        return caliber;
    }

    /// @inheritdoc IBridgeAdapterFactory
    function createBridgeAdapter(uint16 bridgeId, bytes calldata initData) external returns (address adapter) {
        if (!_getCaliberFactoryStorage()._isCaliberMailbox[msg.sender]) {
            revert NotCaliberMailbox();
        }
        return _createBridgeAdapter(msg.sender, bridgeId, initData);
    }
}
