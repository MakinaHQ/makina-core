// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {BridgeAdapterFactory} from "./BridgeAdapterFactory.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeAdapterFactory} from "../interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {IHubRegistry} from "../interfaces/IHubRegistry.sol";
import {IMachineFactory} from "../interfaces/IMachineFactory.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IMakinaGovernable} from "../interfaces/IMakinaGovernable.sol";
import {IOwnable2Step} from "../interfaces/IOwnable2Step.sol";
import {IPreDepositVault} from "../interfaces/IPreDepositVault.sol";
import {MachineShare} from "../machine/MachineShare.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";
import {Constants} from "../libraries/Constants.sol";

contract MachineFactory is AccessManagedUpgradeable, BridgeAdapterFactory, IMachineFactory {
    /// @inheritdoc IMachineFactory
    mapping(address preDepositVault => bool isPreDepositVault) public isPreDepositVault;
    /// @inheritdoc IMachineFactory
    mapping(address machine => bool isMachine) public isMachine;
    /// @inheritdoc IMachineFactory
    mapping(address machine => bool isCaliber) public isCaliber;

    constructor(address _registry) MakinaContext(_registry) {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc IMachineFactory
    function createPreDepositVault(
        IPreDepositVault.PreDepositVaultInitParams calldata params,
        string memory tokenName,
        string memory tokenSymbol
    ) external override restricted returns (address) {
        address shareToken = _createShareToken(tokenName, tokenSymbol, address(this));
        address preDepositVault = address(new BeaconProxy(IHubRegistry(registry).preDepositVaultBeacon(), ""));
        IOwnable2Step(shareToken).transferOwnership(preDepositVault);

        IPreDepositVault(preDepositVault).initialize(params, shareToken);

        isPreDepositVault[preDepositVault] = true;

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
        if (!isPreDepositVault[preDepositVault]) {
            revert NotPreDepositVault();
        }

        address machine = address(new BeaconProxy(IHubRegistry(registry).machineBeacon(), ""));
        address caliber = _createCaliber(cParams, machine);

        IPreDepositVault(preDepositVault).setPendingMachine(machine);
        address token = IPreDepositVault(preDepositVault).shareToken();

        IMachine(machine).initialize(mParams, mgParams, preDepositVault, token, caliber);

        isMachine[machine] = true;
        isCaliber[caliber] = true;

        emit MachineDeployed(machine, token, caliber);

        return machine;
    }

    /// @inheritdoc IMachineFactory
    function createMachine(
        IMachine.MachineInitParams calldata mParams,
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        string memory tokenName,
        string memory tokenSymbol
    ) external override restricted returns (address) {
        address token = _createShareToken(tokenName, tokenSymbol, address(this));
        address machine = address(new BeaconProxy(IHubRegistry(registry).machineBeacon(), ""));
        address caliber = _createCaliber(cParams, machine);

        IOwnable2Step(token).transferOwnership(machine);

        IMachine(machine).initialize(mParams, mgParams, address(0), token, caliber);

        isMachine[machine] = true;
        isCaliber[caliber] = true;

        emit MachineDeployed(machine, token, caliber);

        return machine;
    }

    /// @inheritdoc IBridgeAdapterFactory
    function createBridgeAdapter(IBridgeAdapter.Bridge bridgeId, bytes calldata initData)
        external
        returns (address adapter)
    {
        if (!isMachine[msg.sender]) {
            revert NotMachine();
        }
        return _createBridgeAdapter(msg.sender, bridgeId, initData);
    }

    /// @dev Deploys a caliber.
    function _createCaliber(ICaliber.CaliberInitParams calldata cParams, address machine) internal returns (address) {
        address caliber = address(
            new BeaconProxy(
                IHubRegistry(registry).caliberBeacon(), abi.encodeCall(ICaliber.initialize, (cParams, machine))
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
        address _shareToken = address(new MachineShare(name, symbol, Constants.SHARE_TOKEN_DECIMALS, initialOwner));
        emit ShareTokenDeployed(_shareToken);
        return _shareToken;
    }
}
