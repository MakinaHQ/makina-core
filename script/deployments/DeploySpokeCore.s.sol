// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {DeployCore} from "./DeployCore.s.sol";

import {ICoreRegistry} from "../../src/interfaces/ICoreRegistry.sol";

/// @notice Deploys the Makina spoke core and runs its registry and AccessManager setup in a single broadcast.
///
/// Env vars (unless `setFilenames` was called):
///   SPOKE_CORE_INPUT_FILENAME  - spoke core input file holding the deployment parameters
///                                (under script/deployments/inputs/spoke-cores/)
///   SPOKE_CORE_OUTPUT_FILENAME - spoke core output file to write the deployed contract addresses to
///                                (under script/deployments/outputs/spoke-cores/)
///   SKIP_AM_SETUP (optional)   - if true, skips the AccessManager function roles and role grants setup,
///                                leaving the deployer as sole admin (for staging deployments)
contract DeploySpokeCore is DeployCore {
    SpokeCore private _core;
    UpgradeableBeacon[] private _bridgeAdapterBeacons;
    TransparentUpgradeableProxy[] private _bridgeConfigs;

    function deployment() public view returns (SpokeCore memory, UpgradeableBeacon[] memory) {
        return (_core, _bridgeAdapterBeacons);
    }

    function _coreSetup() internal override {
        uint256 hubChainId = vm.parseJsonUint(inputJson, ".hubChainId");
        _core = deploySpokeCore(deployer, hubChainId);

        setupSpokeCoreRegistry(_core);
        setupOracleRegistry(_core.oracleRegistry, priceFeedRoutes);
        setupTokenRegistry(_core.tokenRegistry, tokensToRegister);
        setupSwapModule(_core.swapModule, swappersData);
        (_bridgeAdapterBeacons, _bridgeConfigs) =
            deployAndSetupBridges(_core.accessManager, ICoreRegistry(address(_core.spokeCoreRegistry)), bridgesData);

        if (!skipAMSetup) {
            setupSpokeCoreAMFunctionRoles(_core);
            setupAccessManagerRoles(
                _core.accessManager, superAdminRoleGrant, otherRoleGrants, address(_core.spokeCoreFactory), deployer
            );
        }

        // Transfer the ownership of the AccessManager's proxy admin to the AccessManager itself.
        transferAccessManagerOwnership(_core.accessManager);
    }

    function _writeOutput() internal override {
        string memory key = "key-deploy-makina-core-spoke-output-file";

        vm.serializeAddress(key, "AccessManager", address(_core.accessManager));
        vm.serializeAddress(key, "CaliberBeacon", address(_core.caliberBeacon));
        vm.serializeAddress(key, "SpokeCoreFactory", address(_core.spokeCoreFactory));
        vm.serializeAddress(key, "CaliberMailboxBeacon", address(_core.caliberMailboxBeacon));
        vm.serializeAddress(key, "SpokeCoreRegistry", address(_core.spokeCoreRegistry));
        vm.serializeAddress(key, "OracleRegistry", address(_core.oracleRegistry));
        vm.serializeAddress(key, "TokenRegistry", address(_core.tokenRegistry));
        vm.serializeAddress(key, "SwapModule", address(_core.swapModule));
        string memory bridgeAdapterBeaconList;
        string memory babKey = "key-bridge-adapter-beacon-list";
        string memory bridgeConfigList;
        string memory bcKey = "key-bridge-config-list";
        for (uint256 i; i < bridgesData.length; ++i) {
            bridgeAdapterBeaconList =
                vm.serializeAddress(babKey, vm.toString(bridgesData[i].bridgeId), address(_bridgeAdapterBeacons[i]));
            bridgeConfigList =
                vm.serializeAddress(bcKey, vm.toString(bridgesData[i].bridgeId), address(_bridgeConfigs[i]));
        }
        vm.serializeString(key, "BridgeAdapterBeacons", bridgeAdapterBeaconList);
        vm.writeJson(vm.serializeString(key, "BridgeConfigs", bridgeConfigList), outputPath);
    }

    function _recordDir() internal pure override returns (string memory) {
        return "spoke-cores";
    }

    function _loadFilenamesFromEnv() internal override {
        setFilenames(vm.envString("SPOKE_CORE_INPUT_FILENAME"), vm.envString("SPOKE_CORE_OUTPUT_FILENAME"));
    }
}
