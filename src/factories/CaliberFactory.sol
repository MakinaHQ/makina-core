// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ICaliberFactory} from "../interfaces/ICaliberFactory.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";

contract CaliberFactory is AccessManagedUpgradeable, ICaliberFactory {
    address public immutable caliberBeacon;

    mapping(address caliber => bool isCaliber) public isCaliber;

    constructor(address _caliberBeacon) {
        caliberBeacon = _caliberBeacon;
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    function deployCaliber(
        address hubMachine,
        address accountingToken,
        uint256 acountingTokenPosID,
        bytes32 initialAllowedInstrRoot,
        uint256 initialTimelockDuration,
        address initialMechanic,
        address initialSecurityCouncil
    ) external override restricted returns (address) {
        address caliber = address(
            new BeaconProxy(
                caliberBeacon,
                abi.encodeWithSelector(
                    ICaliber(address(0)).initialize.selector,
                    hubMachine,
                    accountingToken,
                    acountingTokenPosID,
                    initialAllowedInstrRoot,
                    initialTimelockDuration,
                    initialMechanic,
                    initialSecurityCouncil,
                    authority()
                )
            )
        );
        isCaliber[caliber] = true;
        return caliber;
    }
}
