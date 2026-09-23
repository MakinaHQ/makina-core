// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SetupForeignCore} from "./SetupForeignCore.s.sol";

import {ICoreRegistry} from "../../src/interfaces/ICoreRegistry.sol";
import {ISpokeCoreRegistry} from "../../src/interfaces/ISpokeCoreRegistry.sol";
import {Roles} from "../../src/libraries/Roles.sol";

/// @notice Wires the spoke core deployed by `DeployForeignSpokeCore`, see `SetupForeignCore`.
contract SetupForeignSpokeCore is SetupForeignCore {
    function _buildCalls() internal override {
        BridgeData[] memory bridgesData = parseBridgesData(inputJson, ".bridgesTargets");
        SwapperData[] memory swappersData = parseSwappersData(inputJson, ".swappersTargets");
        SharedCore memory shared = _sharedCore(bridgesData);

        address registry = _deployed("SpokeCoreRegistry");
        address factory = _deployed("SpokeCoreFactory");
        address swapModule = _deployed("SwapModule");
        address caliberBeacon = _deployed("CaliberBeacon");
        address caliberMailboxBeacon = _deployed("CaliberMailboxBeacon");

        // Registry wiring. OracleRegistry and TokenRegistry were set at initialization.
        _pushCall("SpokeCoreRegistry.setCoreFactory", registry, abi.encodeCall(ICoreRegistry.setCoreFactory, (factory)));
        _pushCall(
            "SpokeCoreRegistry.setSwapModule", registry, abi.encodeCall(ICoreRegistry.setSwapModule, (swapModule))
        );
        _pushCall(
            "SpokeCoreRegistry.setCaliberBeacon",
            registry,
            abi.encodeCall(ICoreRegistry.setCaliberBeacon, (caliberBeacon))
        );
        _pushCall(
            "SpokeCoreRegistry.setCaliberMailboxBeacon",
            registry,
            abi.encodeCall(ISpokeCoreRegistry.setCaliberMailboxBeacon, (caliberMailboxBeacon))
        );
        _pushBridgeCalls("SpokeCoreRegistry", registry, shared);
        _pushSwapperCalls(swapModule, swappersData);

        // AccessManager function roles
        address accessManager = shared.accessManager;
        _pushProxyAdminRoles(accessManager, "SpokeCoreRegistry", registry, "SpokeCoreFactory", factory, swapModule);
        _pushBeaconRole(accessManager, "CaliberBeacon", caliberBeacon);
        _pushBeaconRole(accessManager, "CaliberMailboxBeacon", caliberMailboxBeacon);
        _pushBridgeAdapterBeaconRoles(accessManager, shared.bridgeIds);
        _pushSetTargetFunctionRole(
            accessManager, "SpokeCoreRegistry", registry, _spokeCoreRegistryAMSelectors(), Roles.INFRA_UPGRADE_ROLE
        );
        _pushSetTargetFunctionRole(
            accessManager, "SwapModule", swapModule, _swapModuleAMSelectors(), Roles.INFRA_CONFIG_ROLE
        );
        _pushSetTargetFunctionRole(
            accessManager, "SpokeCoreFactory", factory, _spokeCoreFactoryAMSelectors(), Roles.STRATEGY_DEPLOYMENT_ROLE
        );
        _pushGrantAdminRole(accessManager, "SpokeCoreFactory", factory);
    }

    function _recordDir() internal pure override returns (string memory) {
        return "spoke-cores";
    }

    function _loadFilenamesFromEnv() internal override {
        setFilenames(vm.envString("SPOKE_CORE_INPUT_FILENAME"), vm.envString("SPOKE_CORE_OUTPUT_FILENAME"));
    }
}
