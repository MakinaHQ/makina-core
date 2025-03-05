// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {DeployMakinaCore} from "./DeployMakinaCore.s.sol";

contract DeployMakinaCoreSpoke is DeployMakinaCore {
    using stdJson for string;

    SpokeCore public _deployment;

    constructor() {
        paramsFilename = vm.envString("SPOKE_CORE_PARAMS_FILENAME");
        outputFilename = vm.envString("SPOKE_CORE_OUTPUT_FILENAME");

        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/script/constants/");

        // load input params
        paramsPath = string.concat(basePath, "spoke-core-params/");
        paramsPath = string.concat(paramsPath, paramsFilename);
        paramsJson = vm.readFile(paramsPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "output/DeployMakinaCore-Spoke-");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function deployment() public view returns (SpokeCore memory) {
        return _deployment;
    }

    function _coreSetup() public override {
        uint256 hubChainId = abi.decode(vm.parseJson(paramsJson, ".hubChainId"), (uint256));
        _deployment = deploySpokeCore(deployer, dao, hubChainId);
        setupSpokeRegistry(_deployment);
        setupOracleRegistry(_deployment.oracleRegistry, priceFeedData);
        setupSwapper(_deployment.swapper, dexAggregatorsData);
    }

    function _deploySetupAfter() public override {
        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-makina-core-spoke-output-file";

        // write to file;
        vm.writeJson(vm.serializeAddress(key, "AccessManager", address(_deployment.accessManager)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "CaliberBeacon", address(_deployment.spokeCaliberBeacon)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "CaliberFactory", address(_deployment.caliberFactory)), outputPath);
        vm.writeJson(
            vm.serializeAddress(key, "SpokeCaliberMailboxBeacon", address(_deployment.spokeCaliberMailboxBeacon)),
            outputPath
        );
        vm.writeJson(vm.serializeAddress(key, "SpokeRegistry", address(_deployment.spokeRegistry)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "OracleRegistry", address(_deployment.oracleRegistry)), outputPath);
        vm.writeJson(vm.serializeAddress(key, "Swapper", address(_deployment.swapper)), outputPath);
    }
}
