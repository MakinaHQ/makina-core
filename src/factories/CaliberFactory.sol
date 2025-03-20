// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ISpokeRegistry} from "../interfaces/ISpokeRegistry.sol";
import {ICaliberFactory} from "../interfaces/ICaliberFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";

contract CaliberFactory is AccessManagedUpgradeable, ICaliberFactory {
    /// @inheritdoc ICaliberFactory
    address public immutable registry;

    /// @inheritdoc ICaliberFactory
    mapping(address caliber => bool isCaliber) public isCaliber;

    constructor(address _registry) {
        registry = _registry;
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc ICaliberFactory
    function createCaliber(ICaliber.CaliberInitParams calldata params) external override restricted returns (address) {
        address caliber = address(
            new BeaconProxy(
                ISpokeRegistry(registry).caliberBeacon(),
                abi.encodeCall(ICaliber.initialize, (params, ISpokeRegistry(registry).spokeCaliberMailboxBeacon()))
            )
        );
        isCaliber[caliber] = true;
        emit CaliberDeployed(caliber);
        return caliber;
    }
}
