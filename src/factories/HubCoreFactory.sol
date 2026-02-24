// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import {BridgeAdapterFactory} from "./BridgeAdapterFactory.sol";
import {CaliberFactory} from "./CaliberFactory.sol";
import {IBridgeAdapterFactory} from "../interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {IFeeManager} from "../interfaces/IFeeManager.sol";
import {IHubCoreRegistry} from "../interfaces/IHubCoreRegistry.sol";
import {IHubCoreFactory} from "../interfaces/IHubCoreFactory.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IMakinaGovernable} from "../interfaces/IMakinaGovernable.sol";
import {IOwnable2Step} from "../interfaces/IOwnable2Step.sol";
import {IPreDepositVault} from "../interfaces/IPreDepositVault.sol";
import {MachineShare} from "../machine/MachineShare.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";
import {Roles} from "../libraries/Roles.sol";
import {Errors} from "../libraries/Errors.sol";

contract HubCoreFactory is AccessManagedUpgradeable, CaliberFactory, BridgeAdapterFactory, IHubCoreFactory {
    /// @custom:storage-location erc7201:makina.storage.HubCoreFactory
    struct HubCoreFactoryStorage {
        mapping(address preDepositVault => bool isPreDepositVault) _isPreDepositVault;
        mapping(address machine => bool isMachine) _isMachine;
        mapping(address machine => bytes32 salt) _instanceSalts;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.HubCoreFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HubCoreFactoryStorageLocation =
        0xa73526acc519facb543e3fac63cbe361155292db6c01a81eec358613ec9ee100;

    function _getHubCoreFactoryStorage() internal pure returns (HubCoreFactoryStorage storage $) {
        assembly {
            $.slot := HubCoreFactoryStorageLocation
        }
    }

    constructor(address _registry) MakinaContext(_registry) {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc IHubCoreFactory
    function isMachine(address machine) external view override returns (bool) {
        return _getHubCoreFactoryStorage()._isMachine[machine];
    }

    /// @inheritdoc IHubCoreFactory
    function isPreDepositVault(address preDepositVault) external view override returns (bool) {
        return _getHubCoreFactoryStorage()._isPreDepositVault[preDepositVault];
    }

    /// @inheritdoc IHubCoreFactory
    function createPreDepositVault(
        IPreDepositVault.PreDepositVaultInitParams calldata params,
        address depositToken,
        address accountingToken,
        string memory tokenName,
        string memory tokenSymbol,
        bool setupAMFunctionRoles
    ) external override restricted returns (address) {
        HubCoreFactoryStorage storage $ = _getHubCoreFactoryStorage();

        address shareToken = _createShareToken(tokenName, tokenSymbol, address(this));
        address preDepositVault = address(new BeaconProxy(IHubCoreRegistry(registry).preDepositVaultBeacon(), ""));
        IOwnable2Step(shareToken).transferOwnership(preDepositVault);

        IPreDepositVault(preDepositVault).initialize(params, shareToken, depositToken, accountingToken);

        $._isPreDepositVault[preDepositVault] = true;

        if (setupAMFunctionRoles) {
            _setupPreDepositVaultAMFunctionRoles(params.initialAuthority, preDepositVault);
        }

        emit PreDepositVaultCreated(preDepositVault, shareToken);

        return preDepositVault;
    }

    /// @inheritdoc IHubCoreFactory
    function createMachineFromPreDeposit(
        IMachine.MachineInitParams calldata mParams,
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        BridgeAdapterInitParams[] calldata baParams,
        address preDepositVault,
        bytes32 salt,
        bool setupAMFunctionRoles
    ) external override restricted returns (address) {
        HubCoreFactoryStorage storage $ = _getHubCoreFactoryStorage();

        if (!$._isPreDepositVault[preDepositVault]) {
            revert Errors.NotPreDepositVault();
        }
        address accountingToken = IPreDepositVault(preDepositVault).accountingToken();
        address shareToken = IPreDepositVault(preDepositVault).shareToken();

        address machine = address(new BeaconProxy(IHubCoreRegistry(registry).machineBeacon(), ""));
        address caliber = _createCaliber(cParams, accountingToken, machine, salt);

        IPreDepositVault(preDepositVault).setPendingMachine(machine);

        IMachine(machine).initialize(mParams, mgParams, preDepositVault, shareToken, accountingToken, caliber);

        $._isMachine[machine] = true;
        $._instanceSalts[machine] = salt;

        for (uint256 i; i < baParams.length; ++i) {
            _createBridgeAdapter(machine, baParams[i], salt);
        }

        if (setupAMFunctionRoles) {
            address initialAuthority = mgParams.initialAuthority;
            address initialFeeManager = mParams.initialFeeManager;
            _setupMachineBundleAMFunctionRoles(initialAuthority, machine, caliber, initialFeeManager);
        }

        emit MachineCreated(machine, shareToken);

        return machine;
    }

    /// @inheritdoc IHubCoreFactory
    function createMachine(
        IMachine.MachineInitParams calldata mParams,
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        BridgeAdapterInitParams[] calldata baParams,
        address accountingToken,
        string memory tokenName,
        string memory tokenSymbol,
        bytes32 salt,
        bool setupAMFunctionRoles
    ) external override restricted returns (address) {
        address shareToken = _createShareToken(tokenName, tokenSymbol, address(this));
        address machine = address(new BeaconProxy(IHubCoreRegistry(registry).machineBeacon(), ""));
        address caliber = _createCaliber(cParams, accountingToken, machine, salt);

        IOwnable2Step(shareToken).transferOwnership(machine);

        IMachine(machine).initialize(mParams, mgParams, address(0), shareToken, accountingToken, caliber);

        {
            HubCoreFactoryStorage storage $ = _getHubCoreFactoryStorage();
            $._isMachine[machine] = true;
            $._instanceSalts[machine] = salt;
        }

        for (uint256 i; i < baParams.length; ++i) {
            _createBridgeAdapter(machine, baParams[i], salt);
        }

        if (setupAMFunctionRoles) {
            address initialAuthority = mgParams.initialAuthority;
            address initialFeeManager = mParams.initialFeeManager;
            _setupMachineBundleAMFunctionRoles(initialAuthority, machine, caliber, initialFeeManager);
        }

        emit MachineCreated(machine, shareToken);

        return machine;
    }

    /// @inheritdoc IBridgeAdapterFactory
    function createBridgeAdapter(address bridgeController, BridgeAdapterInitParams calldata baParams)
        external
        override
        restricted
        returns (address)
    {
        HubCoreFactoryStorage storage $ = _getHubCoreFactoryStorage();
        if (!$._isMachine[bridgeController]) {
            revert Errors.InvalidBridgeController();
        }

        return _createBridgeAdapter(bridgeController, baParams, $._instanceSalts[bridgeController]);
    }

    /// @dev Deploys a machine share token.
    function _createShareToken(string memory name, string memory symbol, address initialOwner)
        internal
        returns (address)
    {
        address _shareToken = address(new MachineShare(name, symbol, initialOwner));
        emit ShareTokenCreated(_shareToken);
        return _shareToken;
    }

    /// @dev Sets function roles for a deployed pre-deposit vault instance.
    function _setupPreDepositVaultAMFunctionRoles(address _authority, address _preDepositVault) internal {
        _checkAuthority(_authority);

        bytes4[] memory mgmtSetupSelectors = new bytes4[](1);
        mgmtSetupSelectors[0] = IMakinaGovernable.setRiskManager.selector;
        IAccessManager(_authority).setTargetFunctionRole(
            _preDepositVault, mgmtSetupSelectors, Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );
    }

    /// @dev Sets function roles for a deployed machine instance, its hub caliber, and its initial fee manager if applicable.
    function _setupMachineBundleAMFunctionRoles(
        address _authority,
        address _machine,
        address _caliber,
        address _initialFeeManager
    ) internal {
        _checkAuthority(_authority);

        _setupMachineAMFunctionRoles(_authority, _machine);
        _setupCaliberAMFunctionRoles(_authority, _caliber);
        _setupInitialFeeManagerAMFunctionRoles(_authority, _initialFeeManager);
    }

    /// @dev Sets function roles for a deployed machine instance.
    function _setupMachineAMFunctionRoles(address _authority, address _machine) internal {
        bytes4[] memory compSetupSelectors = new bytes4[](5);
        compSetupSelectors[0] = IMachine.setSpokeCaliber.selector;
        compSetupSelectors[1] = IMachine.setSpokeBridgeAdapter.selector;
        compSetupSelectors[2] = IMachine.setDepositor.selector;
        compSetupSelectors[3] = IMachine.setRedeemer.selector;
        compSetupSelectors[4] = IMachine.setFeeManager.selector;
        IAccessManager(_authority).setTargetFunctionRole(
            _machine, compSetupSelectors, Roles.STRATEGY_COMPONENTS_SETUP_ROLE
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
            _machine, mgmtSetupSelectors, Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );
    }

    /// @dev Sets function roles for the initial fee manager of a deployed machine instance if applicable.
    function _setupInitialFeeManagerAMFunctionRoles(address _authority, address _feeManager) internal {
        if (_feeManager != address(0)) {
            bytes4[] memory compSetupSelectors = IFeeManager(_feeManager).getRestrictedFeeConfigSelectors();
            if (compSetupSelectors.length > 0) {
                IAccessManager(_authority).setTargetFunctionRole(
                    _feeManager, compSetupSelectors, Roles.STRATEGY_COMPONENTS_SETUP_ROLE
                );
            }
        }
    }

    /// @dev Checks that the provided authority matches the current authority.
    function _checkAuthority(address _authority) internal view {
        if (_authority != authority()) {
            revert Errors.NotFactoryAuthority();
        }
    }
}
