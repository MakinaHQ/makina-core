// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IBaseMakinaRegistry} from "../interfaces/IBaseMakinaRegistry.sol";
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
    function deployCaliber(
        address hubMachineInbox,
        address accountingToken,
        uint256 accountingTokenPosId,
        uint256 initialPositionStaleThreshold,
        bytes32 initialAllowedInstrRoot,
        uint256 initialTimelockDuration,
        uint256 initialMaxMgmtLossBps,
        uint256 initialMaxSwapLossBps,
        address initialMechanic,
        address initialSecurityCouncil,
        address initialAuthority
    ) external override restricted returns (address) {
        ICaliber.InitParams memory params = ICaliber.InitParams({
            hubMachineInbox: hubMachineInbox,
            accountingToken: accountingToken,
            accountingTokenPosId: accountingTokenPosId,
            initialPositionStaleThreshold: initialPositionStaleThreshold,
            initialAllowedInstrRoot: initialAllowedInstrRoot,
            initialTimelockDuration: initialTimelockDuration,
            initialMaxMgmtLossBps: initialMaxMgmtLossBps,
            initialMaxSwapLossBps: initialMaxSwapLossBps,
            initialMechanic: initialMechanic,
            initialSecurityCouncil: initialSecurityCouncil,
            initialAuthority: initialAuthority
        });
        address caliber = address(
            new BeaconProxy(
                IBaseMakinaRegistry(registry).caliberBeacon(), abi.encodeCall(ICaliber.initialize, (params))
            )
        );
        isCaliber[caliber] = true;
        emit CaliberDeployed(caliber);
        return caliber;
    }
}
