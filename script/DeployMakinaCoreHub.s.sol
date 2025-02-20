// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/StdJson.sol";
import {DeployMakinaCoreShared} from "./DeployMakinaCoreShared.s.sol";

contract DeployMakinaCoreHub is DeployMakinaCoreShared {
    using stdJson for string;

    constructor() {
        constantsFilename = vm.envString("HUB_CONSTANTS_FILENAME");
        outputFilename = vm.envString("HUB_OUTPUT_FILENAME");

        string memory root = vm.projectRoot();
        basePath = string.concat(root, "/script/constants/");

        // load constants
        inputPath = string.concat(basePath, constantsFilename);
        jsonConstants = vm.readFile(inputPath);

        // Loading output and use output path to later save deployed contracts
        outputPath = string.concat(basePath, "output/");
        outputPath = string.concat(outputPath, "DeployMakinaCore-Hub-");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function _coreSetup() public override {
        _coreSharedSetup();
        _coreHubSetup();
    }

    function _deploySetupAfter() public override {
        _hubRegistrySetup();
        _setupOracleRegistry();
        _setupSwapper();

        // @TODO setup access manager

        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-makina-core-hub-output-file";

        // write to file;
        vm.writeJson(vm.serializeAddress(key, "AccessManager", address(accessManager)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "CaliberBeacon", address(hubCaliberBeacon)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "MachineBeacon", address(machineBeacon)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "MachineFactory", address(machineFactory)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "HubDualMailboxBeacon", address(hubDualMailboxBeacon)), outputPath);
        vm.writeJson(
            vm.serializeAddress(key, "SpokeMachineMailboxBeacon", address(spokeMachineMailboxBeacon)), outputPath
        );
        vm.writeJson(vm.serializeAddress(key, "HubRegistry", address(hubRegistry)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "OracleRegistry", address(oracleRegistry)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "Swapper", address(swapper)), outputPath);
    }

    function _setupHubRegistry() public {
        hubRegistry.setCaliberBeacon(address(hubCaliberBeacon));
        hubRegistry.setMachineBeacon(address(machineBeacon));
        hubRegistry.setMachineFactory(address(machineFactory));
        hubRegistry.setHubDualMailboxBeacon(address(hubDualMailboxBeacon));
        hubRegistry.setSpokeMachineMailboxBeacon(address(spokeMachineMailboxBeacon));
    }
}
