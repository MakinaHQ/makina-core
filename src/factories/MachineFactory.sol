// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {BridgeAdapterFactory} from "./BridgeAdapterFactory.sol";
import {IBridgeAdapterFactory} from "../interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {IHubCoreRegistry} from "../interfaces/IHubCoreRegistry.sol";
import {IMachineFactory} from "../interfaces/IMachineFactory.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IMakinaGovernable} from "../interfaces/IMakinaGovernable.sol";
import {IOwnable2Step} from "../interfaces/IOwnable2Step.sol";
import {IPreDepositVault} from "../interfaces/IPreDepositVault.sol";
import {MachineShare} from "../machine/MachineShare.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";
import {DecimalsUtils} from "../libraries/DecimalsUtils.sol";

contract MachineFactory is AccessManagedUpgradeable, BridgeAdapterFactory, IMachineFactory {
    /// @custom:storage-location erc7201:makina.storage.MachineFactory
    struct MachineFactoryStorage {
        mapping(address preDepositVault => bool isPreDepositVault) _isPreDepositVault;
        mapping(address machine => bool isMachine) _isMachine;
        mapping(address machine => bool isCaliber) _isCaliber;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.CaliberMachineFactoryFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MachineFactoryStorageLocation =
        0x092f83b0a9c245bf0116fc4aaf5564ab048ff47d6596f1c61801f18d9dfbea00;

    function _getMachineFactoryStorage() internal pure returns (MachineFactoryStorage storage $) {
        assembly {
            $.slot := MachineFactoryStorageLocation
        }
    }

    constructor(address _registry) MakinaContext(_registry) {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc IMachineFactory
    function isCaliber(address caliber) external view override returns (bool) {
        return _getMachineFactoryStorage()._isCaliber[caliber];
    }

    /// @inheritdoc IMachineFactory
    function isMachine(address machine) external view override returns (bool) {
        return _getMachineFactoryStorage()._isMachine[machine];
    }

    /// @inheritdoc IMachineFactory
    function isPreDepositVault(address preDepositVault) external view override returns (bool) {
        return _getMachineFactoryStorage()._isPreDepositVault[preDepositVault];
    }

    /// @inheritdoc IMachineFactory
    function createPreDepositVault(
        IPreDepositVault.PreDepositVaultInitParams calldata params,
        address depositToken,
        address accountingToken,
        string memory tokenName,
        string memory tokenSymbol
    ) external override restricted returns (address) {
        MachineFactoryStorage storage $ = _getMachineFactoryStorage();

        address shareToken = _createShareToken(tokenName, tokenSymbol, address(this));
        address preDepositVault = address(new BeaconProxy(IHubCoreRegistry(registry).preDepositVaultBeacon(), ""));
        IOwnable2Step(shareToken).transferOwnership(preDepositVault);

        IPreDepositVault(preDepositVault).initialize(params, shareToken, depositToken, accountingToken);

        $._isPreDepositVault[preDepositVault] = true;

        emit PreDepositVaultDeployed(preDepositVault, shareToken);

        return preDepositVault;
    }

    /// @inheritdoc IMachineFactory
    function createMachineFromPreDeposit(
        IMachine.MachineInitParams calldata mParams,
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address preDepositVault
    ) external override restricted returns (address) {
        MachineFactoryStorage storage $ = _getMachineFactoryStorage();

        if (!$._isPreDepositVault[preDepositVault]) {
            revert NotPreDepositVault();
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

    /// @inheritdoc IMachineFactory
    function createMachine(
        IMachine.MachineInitParams calldata mParams,
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address accountingToken,
        string memory tokenName,
        string memory tokenSymbol
    ) external override restricted returns (address) {
        MachineFactoryStorage storage $ = _getMachineFactoryStorage();

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
        if (!_getMachineFactoryStorage()._isMachine[msg.sender]) {
            revert NotMachine();
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
