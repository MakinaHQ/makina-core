// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {DeployCore} from "./DeployCore.s.sol";

import {ICoreRegistry} from "../../src/interfaces/ICoreRegistry.sol";

contract DeploySpokeCore is DeployCore {
    using stdJson for string;

    SpokeCore private _core;
    UpgradeableBeacon[] private _bridgeAdapterBeacons;
    TransparentUpgradeableProxy[] private _bridgeConfigs;

    constructor() {
        string memory inputFilename = vm.envString("SPOKE_INPUT_FILENAME");
        string memory outputFilename = vm.envString("SPOKE_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/spoke-cores/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "outputs/spoke-cores/");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function deployment() public view returns (SpokeCore memory, UpgradeableBeacon[] memory) {
        return (_core, _bridgeAdapterBeacons);
    }

    function _coreSetup() public override {
        uint256 hubChainId = abi.decode(vm.parseJson(inputJson, ".hubChainId"), (uint256));
        _core = deploySpokeCore(deployer, hubChainId);

        setupSpokeCoreRegistry(_core);
        setupOracleRegistry(_core.oracleRegistry, priceFeedRoutes);
        setupTokenRegistry(_core.tokenRegistry, tokensToRegister);
        setupSwapModule(_core.swapModule, swappersData);
        (_bridgeAdapterBeacons, _bridgeConfigs) =
            deployAndSetupBridges(_core.accessManager, ICoreRegistry(address(_core.spokeCoreRegistry)), bridgesData, vm);

        if (!vm.envOr("SKIP_AM_SETUP", false)) {
            setupSpokeCoreAMFunctionRoles(_core, vm);
            setupAccessManagerRoles(_core.accessManager, superAdminRoleGrant, otherRoleGrants, deployer);
            transferAccessManagerOwnership(_core.accessManager, vm);
        }
    }

    function _deploySetupAfter() public override {
        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-makina-core-spoke-output-file";

        // write to file
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
}
