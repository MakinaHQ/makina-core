// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {DeployCore} from "./DeployCore.s.sol";

import {ICoreRegistry} from "../../src/interfaces/ICoreRegistry.sol";

contract DeployHubCore is DeployCore {
    using stdJson for string;

    HubCore private _core;
    UpgradeableBeacon[] private _bridgeAdapterBeacons;
    TransparentUpgradeableProxy[] private _bridgeConfigs;

    constructor() {
        string memory inputFilename = vm.envString("HUB_INPUT_FILENAME");
        string memory outputFilename = vm.envString("HUB_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/hub-cores/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "outputs/hub-cores/");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function deployment() public view returns (HubCore memory, UpgradeableBeacon[] memory) {
        return (_core, _bridgeAdapterBeacons);
    }

    function _coreSetup() public override {
        address wormhole = abi.decode(vm.parseJson(inputJson, ".wormhole"), (address));
        uint256[] memory supportedChains = abi.decode(vm.parseJson(inputJson, ".supportedChains"), (uint256[]));
        _core = deployHubCore(deployer, upgradeAdmin, wormhole);

        setupHubCoreRegistry(_core);
        setupOracleRegistry(_core.oracleRegistry, priceFeedRoutes);
        setupTokenRegistry(_core.tokenRegistry, tokensToRegister);
        setupChainRegistry(_core.chainRegistry, supportedChains);
        setupSwapModule(_core.swapModule, swappersData);
        (_bridgeAdapterBeacons, _bridgeConfigs) = deployAndSetupBridges(
            upgradeAdmin, ICoreRegistry(address(_core.hubCoreRegistry)), _core.accessManager, bridgesData
        );

        if (!vm.envOr("SKIP_AM_SETUP", false)) {
            setupHubCoreAMFunctionRoles(_core);
            setupAccessManagerRoles(
                _core.accessManager,
                superAdmin,
                infraSetupAdmin,
                stratDeployAdmin,
                stratCompSetupAdmin,
                stratMgmtSetupAdmin,
                deployer
            );
        }
    }

    function _deploySetupAfter() public override {
        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-makina-core-hub-output-file";

        // write to file
        vm.serializeAddress(key, "AccessManager", address(_core.accessManager));
        vm.serializeAddress(key, "CaliberBeacon", address(_core.caliberBeacon));
        vm.serializeAddress(key, "MachineBeacon", address(_core.machineBeacon));
        vm.serializeAddress(key, "PreDepositVaultBeacon", address(_core.preDepositVaultBeacon));
        vm.serializeAddress(key, "HubCoreFactory", address(_core.hubCoreFactory));
        vm.serializeAddress(key, "ChainRegistry", address(_core.chainRegistry));
        vm.serializeAddress(key, "HubCoreRegistry", address(_core.hubCoreRegistry));
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
