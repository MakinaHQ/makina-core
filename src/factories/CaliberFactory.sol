// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {BridgeAdapterFactory} from "./BridgeAdapterFactory.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeAdapterFactory} from "../interfaces/IBridgeAdapterFactory.sol";
import {ICaliberFactory} from "../interfaces/ICaliberFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox} from "../interfaces/ICaliberMailbox.sol";
import {IMakinaGovernable} from "../interfaces/IMakinaGovernable.sol";
import {ISpokeRegistry} from "../interfaces/ISpokeRegistry.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

contract CaliberFactory is AccessManagedUpgradeable, BridgeAdapterFactory, ICaliberFactory {
    /// @inheritdoc ICaliberFactory
    mapping(address caliber => bool isCaliber) public isCaliber;
    /// @inheritdoc ICaliberFactory
    mapping(address caliber => bool isCaliber) public isCaliberMailbox;

    constructor(address _registry) MakinaContext(_registry) {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc ICaliberFactory
    function createCaliber(
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address accountingToken,
        address hubMachine
    ) external override restricted returns (address) {
        address mailbox = address(
            new BeaconProxy(
                ISpokeRegistry(registry).caliberMailboxBeacon(),
                abi.encodeCall(ICaliberMailbox.initialize, (mgParams, hubMachine))
            )
        );
        address caliber = address(
            new BeaconProxy(
                ISpokeRegistry(registry).caliberBeacon(),
                abi.encodeCall(ICaliber.initialize, (cParams, accountingToken, mailbox))
            )
        );
        ICaliberMailbox(mailbox).setCaliber(caliber);
        isCaliber[caliber] = true;
        isCaliberMailbox[mailbox] = true;
        emit SpokeCaliberCreated(hubMachine, caliber, mailbox);
        return caliber;
    }

    /// @inheritdoc IBridgeAdapterFactory
    function createBridgeAdapter(IBridgeAdapter.Bridge bridgeId, bytes calldata initData)
        external
        returns (address adapter)
    {
        if (!isCaliberMailbox[msg.sender]) {
            revert NotCaliberMailbox();
        }
        return _createBridgeAdapter(msg.sender, bridgeId, initData);
    }
}
