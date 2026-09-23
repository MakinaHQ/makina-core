// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {DeployForeignCore} from "./DeployForeignCore.s.sol";

/// @notice Deploys the hub core of a foreign instance, see `DeployForeignCore`.
///
/// Env vars (unless `setFilenames` was called):
///   HUB_CORE_INPUT_FILENAME  - input file holding the deployment parameters
///                              (under script/deployments/inputs/hub-cores/)
///   HUB_CORE_OUTPUT_FILENAME - output file to write the deployed contract addresses to
///                              (under script/deployments/outputs/hub-cores/)
contract DeployForeignHubCore is DeployForeignCore {
    HubCore private _core;

    function deployment() public view returns (HubCore memory, UpgradeableBeacon[] memory) {
        return (_core, _bridgeAdapterBeacons);
    }

    function _coreSetup() internal override {
        address creForwarder = vm.parseJsonAddress(inputJson, ".creForwarder");
        (_core, _bridgeAdapterBeacons) = deployForeignHubCore(_sharedCore(), creForwarder, bridgesData);
    }

    /// @dev Deployed contracts only, not the shared ones.
    function _writeOutput() internal override {
        string memory key = "key-deploy-makina-core-foreign-hub-output-file";

        vm.serializeAddress(key, "HubCoreRegistry", address(_core.hubCoreRegistry));
        vm.serializeAddress(key, "HubCoreFactory", address(_core.hubCoreFactory));
        vm.serializeAddress(key, "SwapModule", address(_core.swapModule));
        vm.serializeAddress(key, "CaliberBeacon", address(_core.caliberBeacon));
        vm.serializeAddress(key, "MachineBeacon", address(_core.machineBeacon));
        vm.serializeAddress(key, "PreDepositVaultBeacon", address(_core.preDepositVaultBeacon));
        vm.writeJson(_serializeBridgeAdapterBeacons(key), outputPath);
    }

    function _recordDir() internal pure override returns (string memory) {
        return "hub-cores";
    }

    function _loadFilenamesFromEnv() internal override {
        setFilenames(vm.envString("HUB_CORE_INPUT_FILENAME"), vm.envString("HUB_CORE_OUTPUT_FILENAME"));
    }
}
