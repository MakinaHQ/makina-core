// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {BridgeAdapterFactory} from "./BridgeAdapterFactory.sol";
import {IBridgeAdapterFactory} from "../interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {IHubCoreRegistry} from "../interfaces/IHubCoreRegistry.sol";
import {IHubCoreFactory} from "../interfaces/IHubCoreFactory.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IMakinaGovernable} from "../interfaces/IMakinaGovernable.sol";
import {IOwnable2Step} from "../interfaces/IOwnable2Step.sol";
import {IPreDepositVault} from "../interfaces/IPreDepositVault.sol";
import {MachineShare} from "../machine/MachineShare.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";
import {DecimalsUtils} from "../libraries/DecimalsUtils.sol";
import {Errors} from "../libraries/Errors.sol";

contract HubCoreFactory is AccessManagedUpgradeable, BridgeAdapterFactory, IHubCoreFactory {
    /// @custom:storage-location erc7201:makina.storage.HubCoreFactory
    struct HubCoreFactoryStorage {
        mapping(address preDepositVault => bool isPreDepositVault) _isPreDepositVault;
        mapping(address machine => bool isMachine) _isMachine;
        mapping(address machine => bool isCaliber) _isCaliber;
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
    function isCaliber(address caliber) external view override returns (bool) {
        return _getHubCoreFactoryStorage()._isCaliber[caliber];
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
        string memory tokenSymbol
    ) external override restricted returns (address) {
        HubCoreFactoryStorage storage $ = _getHubCoreFactoryStorage();

        address shareToken = _createShareToken(tokenName, tokenSymbol, address(this));
        address preDepositVault = address(new BeaconProxy(IHubCoreRegistry(registry).preDepositVaultBeacon(), ""));
        IOwnable2Step(shareToken).transferOwnership(preDepositVault);

        IPreDepositVault(preDepositVault).initialize(params, shareToken, depositToken, accountingToken);

        $._isPreDepositVault[preDepositVault] = true;

        emit PreDepositVaultDeployed(preDepositVault, shareToken);

        return preDepositVault;
    }

    /// @inheritdoc IHubCoreFactory
    function createMachineFromPreDeposit(
        IMachine.MachineInitParams calldata mParams,
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address preDepositVault
    ) external override restricted returns (address) {
        HubCoreFactoryStorage storage $ = _getHubCoreFactoryStorage();

        if (!$._isPreDepositVault[preDepositVault]) {
            revert Errors.NotPreDepositVault();
        }
        address accountingToken = IPreDepositVault(preDepositVault).accountingToken();
        address shareToken = IPreDepositVault(preDepositVault).shareToken();

        address machine = address(new BeaconProxy(IHubCoreRegistry(registry).machineBeacon(), ""));
        address caliber = _createCaliber(cParams, accountingToken, machine);

        IPreDepositVault(preDepositVault).setPendingMachine(machine);

        IMachine(machine).initialize(mParams, mgParams, preDepositVault, shareToken, accountingToken, caliber);

        $._isMachine[machine] = true;
        $._isCaliber[caliber] = true;

        emit MachineDeployed(machine, shareToken, caliber);

        return machine;
    }

    /// @inheritdoc IHubCoreFactory
    function createMachine(
        IMachine.MachineInitParams calldata mParams,
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address accountingToken,
        string memory tokenName,
        string memory tokenSymbol
    ) external override restricted returns (address) {
        HubCoreFactoryStorage storage $ = _getHubCoreFactoryStorage();

        address token = _createShareToken(tokenName, tokenSymbol, address(this));
        address machine = address(new BeaconProxy(IHubCoreRegistry(registry).machineBeacon(), ""));
        address caliber = _createCaliber(cParams, accountingToken, machine);

        IOwnable2Step(token).transferOwnership(machine);

        IMachine(machine).initialize(mParams, mgParams, address(0), token, accountingToken, caliber);

        $._isMachine[machine] = true;
        $._isCaliber[caliber] = true;

        emit MachineDeployed(machine, token, caliber);

        return machine;
    }

    /// @inheritdoc IBridgeAdapterFactory
    function createBridgeAdapter(uint16 bridgeId, bytes calldata initData) external returns (address adapter) {
        if (!_getHubCoreFactoryStorage()._isMachine[msg.sender]) {
            revert Errors.NotMachine();
        }
        return _createBridgeAdapter(msg.sender, bridgeId, initData);
    }

    /// @dev Deploys a caliber.
    function _createCaliber(ICaliber.CaliberInitParams calldata cParams, address accountingToken, address machine)
        internal
        returns (address)
    {
        address caliber = address(
            new BeaconProxy(
                IHubCoreRegistry(registry).caliberBeacon(),
                abi.encodeCall(ICaliber.initialize, (cParams, accountingToken, machine))
            )
        );

        emit HubCaliberDeployed(caliber);

        return caliber;
    }

    /// @dev Deploys a machine share token.
    function _createShareToken(string memory name, string memory symbol, address initialOwner)
        internal
        returns (address)
    {
        address _shareToken = address(new MachineShare(name, symbol, DecimalsUtils.SHARE_TOKEN_DECIMALS, initialOwner));
        emit ShareTokenDeployed(_shareToken);
        return _shareToken;
    }
}
