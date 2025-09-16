// SPDX-License-Identifier: BUSL-1.1
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
    // keccak256("makina.salt.CaliberMailbox")
    bytes32 private constant CaliberMailboxSaltDomain =
        0x4b3676c1328bb93bf4cdb2e4a60e8517fd898e78bd01e7956950c3ff62d3872f;

    /// @custom:storage-location erc7201:makina.storage.SpokeCoreFactory
    struct SpokeCoreFactoryStorage {
        mapping(address mailbox => bool isMailbox) _isCaliberMailbox;
        mapping(address mailbox => bytes32 salt) _instanceSalts;
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
        address hubMachine,
        bytes32 salt
    ) external override restricted returns (address) {
        SpokeCoreFactoryStorage storage $ = _getSpokeCoreFactoryStorage();

        address mailbox = _createCaliberMailbox(mgParams, hubMachine, salt);
        address caliber = _createCaliber(cParams, accountingToken, mailbox, salt);

        ICaliberMailbox(mailbox).setCaliber(caliber);
        $._isCaliberMailbox[mailbox] = true;
        $._instanceSalts[mailbox] = salt;

        emit CaliberMailboxCreated(mailbox, caliber, hubMachine);

        return caliber;
    }

    /// @inheritdoc IBridgeAdapterFactory
    function createBridgeAdapter(uint16 bridgeId, bytes calldata initData) external returns (address) {
        SpokeCoreFactoryStorage storage $ = _getSpokeCoreFactoryStorage();
        address caller = msg.sender;
        if (!$._isCaliberMailbox[caller]) {
            revert Errors.NotCaliberMailbox();
        }
        return _createBridgeAdapter(caller, bridgeId, initData, $._instanceSalts[caller]);
    }

    /// @dev Internal logic for caliber mailbox deployment via create3.
    /// This function only performs the deployment. It does not update factory storage nor emit an event.
    function _createCaliberMailbox(
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address hubMachine,
        bytes32 salt
    ) internal returns (address) {
        address beacon = ISpokeCoreRegistry(registry).caliberMailboxBeacon();

        bytes memory initCD = abi.encodeCall(ICaliberMailbox.initialize, (mgParams, hubMachine));
        bytes memory bytecode = abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(beacon, initCD));

        return _create3(CaliberMailboxSaltDomain, salt, bytecode);
    }
}
