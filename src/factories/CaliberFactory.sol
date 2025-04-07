// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ISpokeRegistry} from "../interfaces/ISpokeRegistry.sol";
import {ICaliberFactory} from "../interfaces/ICaliberFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox} from "../interfaces/ICaliberMailbox.sol";

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
    function createCaliber(ICaliber.CaliberInitParams calldata params, address hubMachine)
        external
        override
        restricted
        returns (address)
    {
        address mailbox = address(
            new BeaconProxy(
                ISpokeRegistry(registry).caliberMailboxBeacon(),
                abi.encodeCall(ICaliberMailbox.initialize, (hubMachine))
            )
        );
        address caliber = address(
            new BeaconProxy(
                ISpokeRegistry(registry).caliberBeacon(), abi.encodeCall(ICaliber.initialize, (params, mailbox))
            )
        );
        ICaliberMailbox(mailbox).setCaliber(caliber);
        isCaliber[caliber] = true;
        emit SpokeCaliberCreated(hubMachine, caliber, mailbox);
        return caliber;
    }
}
