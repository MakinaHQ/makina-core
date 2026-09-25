// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SetupForeignCore} from "./base/SetupForeignCore.s.sol";

import {ICoreRegistry} from "../../src/interfaces/ICoreRegistry.sol";
import {IHubCoreRegistry} from "../../src/interfaces/IHubCoreRegistry.sol";
import {Roles} from "../../src/libraries/Roles.sol";

/// @notice Wires the hub core deployed by `DeployForeignHubCore`, see `SetupForeignCore`.
contract SetupForeignHubCore is SetupForeignCore {
    function _buildCalls() internal override {
        BridgeData[] memory bridgesData = parseBridgesData(inputJson, ".bridgesTargets");
        SwapperData[] memory swappersData = parseSwappersData(inputJson, ".swappersTargets");
        SharedCore memory shared = _sharedCore(bridgesData);

        address registry = _deployed("HubCoreRegistry");
        address factory = _deployed("HubCoreFactory");
        address swapModule = _deployed("SwapModule");
        address caliberBeacon = _deployed("CaliberBeacon");
        address machineBeacon = _deployed("MachineBeacon");
        address preDepositVaultBeacon = _deployed("PreDepositVaultBeacon");

        // Registry wiring. OracleRegistry and TokenRegistry were set at initialization.
        _pushCall("HubCoreRegistry.setCoreFactory", registry, abi.encodeCall(ICoreRegistry.setCoreFactory, (factory)));
        _pushCall("HubCoreRegistry.setSwapModule", registry, abi.encodeCall(ICoreRegistry.setSwapModule, (swapModule)));
        _pushCall(
            "HubCoreRegistry.setCaliberBeacon",
            registry,
            abi.encodeCall(ICoreRegistry.setCaliberBeacon, (caliberBeacon))
        );
        _pushCall(
            "HubCoreRegistry.setMachineBeacon",
            registry,
            abi.encodeCall(IHubCoreRegistry.setMachineBeacon, (machineBeacon))
        );
        _pushCall(
            "HubCoreRegistry.setPreDepositVaultBeacon",
            registry,
            abi.encodeCall(IHubCoreRegistry.setPreDepositVaultBeacon, (preDepositVaultBeacon))
        );
        _pushBridgeCalls("HubCoreRegistry", registry, shared);
        _pushSwapperCalls(swapModule, swappersData);

        // AccessManager function roles
        address accessManager = shared.accessManager;
        _pushProxyAdminRoles(accessManager, "HubCoreRegistry", registry, "HubCoreFactory", factory, swapModule);
        _pushBeaconRole(accessManager, "CaliberBeacon", caliberBeacon);
        _pushBeaconRole(accessManager, "MachineBeacon", machineBeacon);
        _pushBeaconRole(accessManager, "PreDepositVaultBeacon", preDepositVaultBeacon);
        _pushBridgeAdapterBeaconRoles(accessManager, shared.bridgeIds);
        _pushSetTargetFunctionRole(
            accessManager, "HubCoreRegistry", registry, _hubCoreRegistryAMSelectors(), Roles.INFRA_UPGRADE_ROLE
        );
        _pushSetTargetFunctionRole(
            accessManager, "SwapModule", swapModule, _swapModuleAMSelectors(), Roles.INFRA_CONFIG_ROLE
        );
        _pushSetTargetFunctionRole(
            accessManager, "HubCoreFactory", factory, _hubCoreFactoryAMSelectors(), Roles.STRATEGY_DEPLOYMENT_ROLE
        );
        _pushGrantAdminRole(accessManager, "HubCoreFactory", factory);
    }

    function _recordDir() internal pure override returns (string memory) {
        return "hub-cores";
    }

    function _loadFilenamesFromEnv() internal override {
        setFilenames(vm.envString("HUB_CORE_INPUT_FILENAME"), vm.envString("HUB_CORE_OUTPUT_FILENAME"));
    }
}
