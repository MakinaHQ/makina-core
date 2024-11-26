// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ICaliberFactory} from "../interfaces/ICaliberFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";

contract CaliberFactory is AccessManagedUpgradeable, ICaliberFactory {
    /// @inheritdoc ICaliberFactory
    address public immutable caliberBeacon;
    /// @inheritdoc ICaliberFactory
    address public immutable caliberInboxBeacon;

    /// @inheritdoc ICaliberFactory
    mapping(address caliber => bool isCaliber) public isCaliber;

    constructor(address _caliberBeacon, address _caliberInboxBeacon) {
        caliberBeacon = _caliberBeacon;
        caliberInboxBeacon = _caliberInboxBeacon;
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc ICaliberFactory
    function deployCaliber(
        address hubMachineInbox,
        address accountingToken,
        uint256 acountingTokenPosID,
        uint256 initialPositionStaleThreshold,
        bytes32 initialAllowedInstrRoot,
        uint256 initialTimelockDuration,
        address initialMechanic,
        address initialSecurityCouncil
    ) external override restricted returns (address) {
        ICaliber.InitParams memory params = ICaliber.InitParams({
            inboxBeacon: caliberInboxBeacon,
            hubMachineInbox: hubMachineInbox,
            accountingToken: accountingToken,
            acountingTokenPosID: acountingTokenPosID,
            initialPositionStaleThreshold: initialPositionStaleThreshold,
            initialAllowedInstrRoot: initialAllowedInstrRoot,
            initialTimelockDuration: initialTimelockDuration,
            initialMechanic: initialMechanic,
            initialSecurityCouncil: initialSecurityCouncil,
            initialAuthority: authority()
        });
        address caliber = address(new BeaconProxy(caliberBeacon, abi.encodeCall(ICaliber.initialize, (params))));
        isCaliber[caliber] = true;
        emit CaliberDeployed(caliber);
        return caliber;
    }
}
