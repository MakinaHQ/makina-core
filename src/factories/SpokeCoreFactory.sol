// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

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
import {Roles} from "../libraries/Roles.sol";

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
        BridgeAdapterInitParams[] calldata baParams,
        address accountingToken,
        address hubMachine,
        bytes32 salt,
        bool setupAMFunctionRoles
    ) external override restricted returns (address) {
        SpokeCoreFactoryStorage storage $ = _getSpokeCoreFactoryStorage();

        address mailbox = _createCaliberMailbox(mgParams, cParams.initialCooldownDuration, hubMachine, salt);
        address caliber = _createCaliber(cParams, accountingToken, mailbox, salt);

        ICaliberMailbox(mailbox).setCaliber(caliber);
        $._isCaliberMailbox[mailbox] = true;
        $._instanceSalts[mailbox] = salt;

        for (uint256 i; i < baParams.length; ++i) {
            _createBridgeAdapter(mailbox, baParams[i], salt);
        }

        if (setupAMFunctionRoles) {
            _setupSpokeCaliberBundleAMFunctionRoles(mgParams.initialAuthority, mailbox, caliber);
        }

        emit CaliberMailboxCreated(mailbox, caliber, hubMachine);

        return caliber;
    }

    /// @inheritdoc IBridgeAdapterFactory
    function createBridgeAdapter(address bridgeController, BridgeAdapterInitParams calldata baParams)
        external
        override
        restricted
        returns (address)
    {
        SpokeCoreFactoryStorage storage $ = _getSpokeCoreFactoryStorage();
        if (!$._isCaliberMailbox[bridgeController]) {
            revert Errors.InvalidBridgeController();
        }

        return _createBridgeAdapter(bridgeController, baParams, $._instanceSalts[bridgeController]);
    }

    /// @dev Internal logic for caliber mailbox deployment via create3.
    /// This function only performs the deployment. It does not update factory storage nor emit an event.
    function _createCaliberMailbox(
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        uint256 initialCooldownDuration,
        address hubMachine,
        bytes32 salt
    ) internal returns (address) {
        address beacon = ISpokeCoreRegistry(registry).caliberMailboxBeacon();

        bytes memory initCD =
            abi.encodeCall(ICaliberMailbox.initialize, (mgParams, initialCooldownDuration, hubMachine));
        bytes memory bytecode = abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(beacon, initCD));

        return _create3(CaliberMailboxSaltDomain, salt, bytecode);
    }

    /// @dev Sets function roles for a deployed machine instance, its hub caliber, and its initial fee manager if applicable.
    function _setupSpokeCaliberBundleAMFunctionRoles(address _authority, address _mailbox, address _caliber) internal {
        _checkAuthority(_authority);

        _setupCaliberMailboxAMFunctionRoles(_authority, _mailbox);
        _setupCaliberAMFunctionRoles(_authority, _caliber);
    }

    /// @dev Sets function roles in associated access manager for a deployed caliber mailbox instance.
    function _setupCaliberMailboxAMFunctionRoles(address _authority, address _mailbox) internal {
        bytes4[] memory compSetupSelectors = new bytes4[](1);
        compSetupSelectors[0] = ICaliberMailbox.setHubBridgeAdapter.selector;
        IAccessManager(_authority).setTargetFunctionRole(
            _mailbox, compSetupSelectors, Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );

        bytes4[] memory mgmtSetupSelectors = new bytes4[](7);
        mgmtSetupSelectors[0] = IMakinaGovernable.setMechanic.selector;
        mgmtSetupSelectors[1] = IMakinaGovernable.setSecurityCouncil.selector;
        mgmtSetupSelectors[2] = IMakinaGovernable.setRiskManager.selector;
        mgmtSetupSelectors[3] = IMakinaGovernable.setRiskManagerTimelock.selector;
        mgmtSetupSelectors[4] = IMakinaGovernable.setRestrictedAccountingMode.selector;
        mgmtSetupSelectors[5] = IMakinaGovernable.addAccountingAgent.selector;
        mgmtSetupSelectors[6] = IMakinaGovernable.removeAccountingAgent.selector;
        IAccessManager(_authority).setTargetFunctionRole(
            _mailbox, mgmtSetupSelectors, Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );
    }

    /// @dev Checks that the provided authority matches the current authority.
    function _checkAuthority(address _authority) internal {
        if (_authority != authority()) {
            revert Errors.NotFactoryAuthority();
        }
    }
}
