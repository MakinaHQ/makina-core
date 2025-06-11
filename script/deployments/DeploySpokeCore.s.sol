// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {DeployCore} from "./DeployCore.s.sol";

import {ICoreRegistry} from "../../src/interfaces/ICoreRegistry.sol";

contract DeploySpokeCore is DeployCore {
    using stdJson for string;

    SpokeCore private _core;
    UpgradeableBeacon[] private _bridgeAdapterBeacons;

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
        _core = deploySpokeCore(deployer, dao, hubChainId);

        setupSpokeCoreRegistry(_core);
        setupOracleRegistry(_core.oracleRegistry, priceFeedRoutes);
        setupTokenRegistry(_core.tokenRegistry, tokensToRegister);
        setupSwapModule(_core.swapModule, swappersData);
        _bridgeAdapterBeacons =
            deployAndSetupBridgeAdapterBeacons(ICoreRegistry(address(_core.spokeCoreRegistry)), bridgesData, dao);

        if (!vm.envBool("SKIP_AM_SETUP")) {
            setupSpokeCoreAMFunctionRoles(_core);
            setupAccessManagerRoles(_core.accessManager, dao, deployer);
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
        for (uint256 i; i < bridgesData.length; ++i) {
            bridgeAdapterBeaconList =
                vm.serializeAddress(babKey, vm.toString(bridgesData[i].bridgeId), address(_bridgeAdapterBeacons[i]));
        }
        vm.writeJson(vm.serializeString(key, "BridgeAdapterBeacons", bridgeAdapterBeaconList), outputPath);
    }
}
