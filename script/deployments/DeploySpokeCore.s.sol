// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {DeployCore} from "./DeployCore.s.sol";

contract DeploySpokeCore is DeployCore {
    using stdJson for string;

    SpokeCore public _deployment;

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

    function deployment() public view returns (SpokeCore memory) {
        return _deployment;
    }

    function _coreSetup() public override {
        uint256 hubChainId = abi.decode(vm.parseJson(inputJson, ".hubChainId"), (uint256));
        _deployment = deploySpokeCore(deployer, dao, hubChainId);

        setupSpokeCoreRegistry(_deployment);
        setupOracleRegistry(_deployment.oracleRegistry, priceFeedRoutes);
        setupTokenRegistry(_deployment.tokenRegistry, tokensToRegister);
        setupSwapModule(_deployment.swapModule, swappersData);

        // @TODO setup access manager
    }

    function _deploySetupAfter() public override {
        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-makina-core-spoke-output-file";

        // write to file;
        vm.serializeAddress(key, "AccessManager", address(_deployment.accessManager));
        vm.serializeAddress(key, "CaliberBeacon", address(_deployment.caliberBeacon));
        vm.serializeAddress(key, "SpokeCoreFactory", address(_deployment.spokeCoreFactory));
        vm.serializeAddress(key, "CaliberMailboxBeacon", address(_deployment.caliberMailboxBeacon));
        vm.serializeAddress(key, "SpokeCoreRegistry", address(_deployment.spokeCoreRegistry));
        vm.serializeAddress(key, "OracleRegistry", address(_deployment.oracleRegistry));
        vm.serializeAddress(key, "TokenRegistry", address(_deployment.tokenRegistry));
        vm.writeJson(vm.serializeAddress(key, "SwapModule", address(_deployment.swapModule)), outputPath);
    }
}
