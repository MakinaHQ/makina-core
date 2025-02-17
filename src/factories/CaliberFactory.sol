// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IHubRegistry} from "../interfaces/IHubRegistry.sol";
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
    function deployCaliber(CaliberDeployParams calldata deployParams) external override restricted returns (address) {
        ICaliber.InitParams memory initParams = ICaliber.InitParams({
            hubMachineEndpoint: deployParams.hubMachineEndpoint,
            mailboxBeacon: IHubRegistry(registry).hubDualMailboxBeacon(),
            accountingToken: deployParams.accountingToken,
            accountingTokenPosId: deployParams.accountingTokenPosId,
            initialPositionStaleThreshold: deployParams.initialPositionStaleThreshold,
            initialAllowedInstrRoot: deployParams.initialAllowedInstrRoot,
            initialTimelockDuration: deployParams.initialTimelockDuration,
            initialMaxPositionIncreaseLossBps: deployParams.initialMaxPositionIncreaseLossBps,
            initialMaxPositionDecreaseLossBps: deployParams.initialMaxPositionDecreaseLossBps,
            initialMaxSwapLossBps: deployParams.initialMaxSwapLossBps,
            initialMechanic: deployParams.initialMechanic,
            initialSecurityCouncil: deployParams.initialSecurityCouncil,
            initialAuthority: deployParams.initialAuthority
        });
        address caliber = address(
            new BeaconProxy(IHubRegistry(registry).caliberBeacon(), abi.encodeCall(ICaliber.initialize, (initParams)))
        );
        isCaliber[caliber] = true;
        emit CaliberDeployed(caliber);
        return caliber;
    }
}
