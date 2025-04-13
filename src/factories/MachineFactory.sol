// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {IHubRegistry} from "../interfaces/IHubRegistry.sol";
import {IMachineFactory} from "../interfaces/IMachineFactory.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IOwnable2Step} from "../interfaces/IOwnable2Step.sol";
import {MachineShare} from "../machine/MachineShare.sol";
import {Constants} from "../libraries/Constants.sol";

contract MachineFactory is AccessManagedUpgradeable, IMachineFactory {
    /// @inheritdoc IMachineFactory
    address public immutable registry;

    /// @inheritdoc IMachineFactory
    mapping(address machine => bool isMachine) public isMachine;
    /// @inheritdoc IMachineFactory
    mapping(address machine => bool isCaliber) public isCaliber;

    constructor(address _registry) {
        registry = _registry;
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc IMachineFactory
    function createMachine(
        IMachine.MachineInitParams calldata params,
        string memory tokenName,
        string memory tokenSymbol
    ) external override restricted returns (address) {
        address token = _createShareToken(tokenName, tokenSymbol, address(this));
        address machine = address(new BeaconProxy(IHubRegistry(registry).machineBeacon(), ""));

        ICaliber.CaliberInitParams memory initParams = ICaliber.CaliberInitParams({
            accountingToken: params.accountingToken,
            initialPositionStaleThreshold: params.hubCaliberPosStaleThreshold,
            initialAllowedInstrRoot: params.hubCaliberAllowedInstrRoot,
            initialTimelockDuration: params.hubCaliberTimelockDuration,
            initialMaxPositionIncreaseLossBps: params.hubCaliberMaxPositionIncreaseLossBps,
            initialMaxPositionDecreaseLossBps: params.hubCaliberMaxPositionDecreaseLossBps,
            initialMaxSwapLossBps: params.hubCaliberMaxSwapLossBps,
            initialFlashLoanModule: params.hubCaliberInitialFlashLoanModule,
            initialMechanic: params.initialMechanic,
            initialSecurityCouncil: params.initialSecurityCouncil,
            initialAuthority: params.initialAuthority
        });

        address caliber = address(
            new BeaconProxy(
                IHubRegistry(registry).caliberBeacon(), abi.encodeCall(ICaliber.initialize, (initParams, machine))
            )
        );

        IOwnable2Step(token).transferOwnership(machine);

        IMachine(machine).initialize(params, token, caliber);

        isMachine[machine] = true;
        isCaliber[caliber] = true;

        emit MachineDeployed(machine, token, caliber);

        return machine;
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
