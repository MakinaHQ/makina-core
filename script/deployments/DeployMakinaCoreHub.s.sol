// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {DeployMakinaCore} from "./DeployMakinaCore.s.sol";

contract DeployMakinaCoreHub is DeployMakinaCore {
    using stdJson for string;

    HubCore public _deployment;

    constructor() {
        paramsFilename = vm.envString("HUB_CORE_PARAMS_FILENAME");
        outputFilename = vm.envString("HUB_CORE_OUTPUT_FILENAME");

        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/script/constants/");

        // load input params
        paramsPath = string.concat(basePath, "hub-core-params/");
        paramsPath = string.concat(paramsPath, paramsFilename);
        paramsJson = vm.readFile(paramsPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "output/DeployMakinaCore-Hub-");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function deployment() public view returns (HubCore memory) {
        return _deployment;
    }

    function _coreSetup() public override {
        address wormhole = abi.decode(vm.parseJson(paramsJson, ".wormhole"), (address));
        _deployment = deployHubCore(deployer, dao, wormhole);

        setupHubRegistry(_deployment);
        setupOracleRegistry(_deployment.oracleRegistry, priceFeedData);
        setupSwapper(_deployment.swapper, dexAggregatorsData);

        // @TODO setup access manager
    }

    function _deploySetupAfter() public override {
        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-makina-core-hub-output-file";

        // write to file;
        vm.writeJson(vm.serializeAddress(key, "AccessManager", address(_deployment.accessManager)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "CaliberBeacon", address(_deployment.hubCaliberBeacon)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "MachineBeacon", address(_deployment.machineBeacon)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "MachineFactory", address(_deployment.machineFactory)), outputPath);
        vm.writeJson(
            vm.serializeAddress(key, "HubDualMailboxBeacon", address(_deployment.hubDualMailboxBeacon)), outputPath
        );
        vm.writeJson(
            vm.serializeAddress(key, "SpokeMachineMailboxBeacon", address(_deployment.spokeMachineMailboxBeacon)),
            outputPath
        );
        vm.writeJson(vm.serializeAddress(key, "HubRegistry", address(_deployment.hubRegistry)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "OracleRegistry", address(_deployment.oracleRegistry)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "Swapper", address(_deployment.swapper)), outputPath);
    }
}
