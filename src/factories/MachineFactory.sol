// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IHubDualMailbox} from "../interfaces/IHubDualMailbox.sol";
import {IHubRegistry} from "../interfaces/IHubRegistry.sol";
import {IMachineFactory} from "../interfaces/IMachineFactory.sol";
import {IMachine} from "../interfaces/IMachine.sol";

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
    function deployMachine(IMachine.MachineInitParams calldata params) external override restricted returns (address) {
        address machine = address(
            new BeaconProxy(IHubRegistry(registry).machineBeacon(), abi.encodeCall(IMachine.initialize, (params)))
        );
        address caliber = IHubDualMailbox(IMachine(machine).hubCaliberMailbox()).caliber();
        isMachine[machine] = true;
        isCaliber[caliber] = true;
        emit MachineDeployed(machine);
        return machine;
    }
}
