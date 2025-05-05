// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {BridgeAdapterFactory} from "./BridgeAdapterFactory.sol";
import {CaliberFactory} from "./CaliberFactory.sol";
import {IBridgeAdapterFactory} from "../interfaces/IBridgeAdapterFactory.sol";
import {ISpokeCoreFactory} from "../interfaces/ISpokeCoreFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox} from "../interfaces/ICaliberMailbox.sol";
import {IMakinaGovernable} from "../interfaces/IMakinaGovernable.sol";
import {ISpokeCoreRegistry} from "../interfaces/ISpokeCoreRegistry.sol";
import {Errors} from "../libraries/Errors.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

contract SpokeCoreFactory is AccessManagedUpgradeable, CaliberFactory, BridgeAdapterFactory, ISpokeCoreFactory {
    /// @custom:storage-location erc7201:makina.storage.SpokeCoreFactory
    struct SpokeCoreFactoryStorage {
        mapping(address caliber => bool isCaliber) _isCaliberMailbox;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.SpokeCoreFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SpokeCoreFactoryStorageLocation =
        0xcb1a6cd67f0aa55e138668b826a3a98a6a6ef973cbafe7a0845e7a69c97a6000;

    function _getSpokeCoreFactoryStorage() internal pure returns (SpokeCoreFactoryStorage storage $) {
        assembly {
            $.slot := SpokeCoreFactoryStorageLocation
        }
    }

    constructor(address _registry) MakinaContext(_registry) {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc ISpokeCoreFactory
    function isCaliberMailbox(address caliberMailbox) external view override returns (bool) {
        return _getSpokeCoreFactoryStorage()._isCaliberMailbox[caliberMailbox];
    }

    /// @inheritdoc ISpokeCoreFactory
    function createCaliber(
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address accountingToken,
        address hubMachine
    ) external override restricted returns (address) {
        SpokeCoreFactoryStorage storage $ = _getSpokeCoreFactoryStorage();

        address mailbox = address(
            new BeaconProxy(
                ISpokeCoreRegistry(registry).caliberMailboxBeacon(),
                abi.encodeCall(ICaliberMailbox.initialize, (mgParams, hubMachine))
            )
        );
        address caliber = _createCaliber(cParams, accountingToken, mailbox);

        ICaliberMailbox(mailbox).setCaliber(caliber);
        $._isCaliberMailbox[mailbox] = true;

        emit CaliberMailboxCreated(mailbox, caliber, hubMachine);

        return caliber;
    }

    /// @inheritdoc IBridgeAdapterFactory
    function createBridgeAdapter(uint16 bridgeId, bytes calldata initData) external returns (address adapter) {
        if (!_getSpokeCoreFactoryStorage()._isCaliberMailbox[msg.sender]) {
            revert Errors.NotCaliberMailbox();
        }
        return _createBridgeAdapter(msg.sender, bridgeId, initData);
    }
}
