// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {SortedParams} from "./utils/SortedParams.sol";

contract DeployTimelockController is Script, SortedParams {
    using stdJson for string;

    string public inputJson;
    string public outputPath;

    address public deployedInstance;

    constructor() {
        string memory inputFilename = vm.envString("TIMELOCK_CONTROLLER_INPUT_FILENAME");
        string memory outputFilename = vm.envString("TIMELOCK_CONTROLLER_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/timelock-controllers/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "outputs/timelock-controllers/");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function run() public {
        TimelockControllerInitParamsSorted memory params =
            abi.decode(vm.parseJson(inputJson), (TimelockControllerInitParamsSorted));

        // start broadcasting transactions
        vm.startBroadcast();

        deployedInstance = address(
            new TimelockController(
                params.initialMinDelay, params.initialProposers, params.initialExecutors, params.initialAdmin
            )
        );

        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-timelock-controller-output-file";
        vm.writeJson(vm.serializeAddress(key, "timelockController", deployedInstance), outputPath);
    }
}
