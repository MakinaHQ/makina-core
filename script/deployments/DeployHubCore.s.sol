// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {DeployCore} from "./DeployCore.s.sol";

contract DeployHubCore is DeployCore {
    using stdJson for string;

    HubCore public _deployment;

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

    function deployment() public view returns (HubCore memory) {
        return _deployment;
    }

    function _coreSetup() public override {
        address wormhole = abi.decode(vm.parseJson(inputJson, ".wormhole"), (address));
        uint256[] memory supportedChains = abi.decode(vm.parseJson(inputJson, ".supportedChains"), (uint256[]));
        _deployment = deployHubCore(deployer, dao, wormhole);

        setupHubRegistry(_deployment);
        setupOracleRegistry(_deployment.oracleRegistry, priceFeedRoutes);
        setupTokenRegistry(_deployment.tokenRegistry, tokensToRegister);
        setupChainRegistry(_deployment.chainRegistry, supportedChains);
        setupSwapModule(_deployment.swapModule, swappersData);

        // @TODO setup access manager
    }

    function _deploySetupAfter() public override {
        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-makina-core-hub-output-file";

        // write to file;
        vm.serializeAddress(key, "AccessManager", address(_deployment.accessManager));
        vm.serializeAddress(key, "CaliberBeacon", address(_deployment.caliberBeacon));
        vm.serializeAddress(key, "MachineBeacon", address(_deployment.machineBeacon));
        vm.serializeAddress(key, "MachineFactory", address(_deployment.machineFactory));
        vm.serializeAddress(key, "ChainRegistry", address(_deployment.chainRegistry));
        vm.serializeAddress(key, "HubRegistry", address(_deployment.hubRegistry));
        vm.serializeAddress(key, "OracleRegistry", address(_deployment.oracleRegistry));
        vm.serializeAddress(key, "TokenRegistry", address(_deployment.tokenRegistry));
        vm.writeJson(vm.serializeAddress(key, "SwapModule", address(_deployment.swapModule)), outputPath);
    }
}
