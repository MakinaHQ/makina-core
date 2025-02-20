// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/StdJson.sol";
import {DeployMakinaCoreShared} from "./DeployMakinaCoreShared.s.sol";

contract DeployMakinaCoreSpoke is DeployMakinaCoreShared {
    using stdJson for string;

    constructor() {
        constantsFilename = vm.envString("SPOKE_CONSTANTS_FILENAME");
        outputFilename = vm.envString("SPOKE_OUTPUT_FILENAME");

        string memory root = vm.projectRoot();
        basePath = string.concat(root, "/script/constants/");

        // load constants
        inputPath = string.concat(basePath, constantsFilename);
        jsonConstants = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "output/");
        outputPath = string.concat(outputPath, "DeployMakinaCore-Spoke-");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function _coreSetup() public override {
        _coreSharedSetup();
        _coreSpokeSetup();
    }

    function _deploySetupAfter() public override {
        _spokeRegistrySetup();
        _setupOracleRegistry();
        _setupSwapper();

        // @TODO setup access manager

        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-makina-core-spoke-output-file";

        // write to file;
        vm.writeJson(vm.serializeAddress(key, "AccessManager", address(accessManager)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "CaliberBeacon", address(spokeCaliberBeacon)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "CaliberFactory", address(spokeCaliberFactory)), outputPath);
        vm.writeJson(
            vm.serializeAddress(key, "SpokeCaliberMailboxBeacon", address(spokeCaliberMailboxBeacon)), outputPath
        );
        vm.writeJson(vm.serializeAddress(key, "SpokeRegistry", address(spokeRegistry)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "OracleRegistry", address(oracleRegistry)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "Swapper", address(swapper)), outputPath);
    }

    function _setupSpokeRegistry() public {
        spokeRegistry.setCaliberBeacon(address(spokeCaliberBeacon));
        spokeRegistry.setCaliberFactory(address(spokeCaliberFactory));
        spokeRegistry.setSpokeCaliberMailboxBeacon(address(spokeCaliberMailboxBeacon));
    }
}
