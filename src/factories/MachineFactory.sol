// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IHubRegistry} from "../interfaces/IHubRegistry.sol";
import {IMachineFactory} from "../interfaces/IMachineFactory.sol";
import {IMachine} from "../interfaces/IMachine.sol";

contract MachineFactory is AccessManagedUpgradeable, IMachineFactory {
    /// @inheritdoc IMachineFactory
    address public immutable registry;

    /// @inheritdoc IMachineFactory
    mapping(address machine => bool isMachine) public isMachine;

    constructor(address _registry) {
        registry = _registry;
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc IMachineFactory
    function deployMachine(
        address _accountingToken,
        address _initialMechanic,
        address _initialSecurityCouncil,
        address _initialAuthority,
        uint256 _initialCaliberStaleThreshold,
        uint256 _hubCaliberAccountingTokenPosID,
        uint256 _hubCaliberPosStaleThreshold,
        bytes32 _hubCaliberAllowedInstrRoot,
        uint256 _hubCaliberTimelockDuration,
        uint256 _hubCaliberMaxMgmtLossBps,
        uint256 _hubCaliberMaxSwapLossBps
    ) external override restricted returns (address) {
        IMachine.MachineInitParams memory params = IMachine.MachineInitParams({
            accountingToken: _accountingToken,
            initialMechanic: _initialMechanic,
            initialSecurityCouncil: _initialSecurityCouncil,
            initialAuthority: _initialAuthority,
            initialCaliberStaleThreshold: _initialCaliberStaleThreshold,
            hubCaliberAccountingTokenPosID: _hubCaliberAccountingTokenPosID,
            hubCaliberPosStaleThreshold: _hubCaliberPosStaleThreshold,
            hubCaliberAllowedInstrRoot: _hubCaliberAllowedInstrRoot,
            hubCaliberTimelockDuration: _hubCaliberTimelockDuration,
            hubCaliberMaxMgmtLossBps: _hubCaliberMaxMgmtLossBps,
            hubCaliberMaxSwapLossBps: _hubCaliberMaxSwapLossBps
        });
        address machine = address(
            new BeaconProxy(IHubRegistry(registry).machineBeacon(), abi.encodeCall(IMachine.initialize, (params)))
        );
        isMachine[machine] = true;
        emit MachineDeployed(machine);
        return machine;
    }
}
