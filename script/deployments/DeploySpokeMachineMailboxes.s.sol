// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineFactory} from "src/interfaces/IMachineFactory.sol";

contract DeploySpokeMachineMailboxes is Script {
    using stdJson for string;

    string machineOutputJson;

    string public inputJson;
    string public outputPath;

    address[] public deployedInstances;

    constructor() {
        string memory inputFilename = vm.envString("HUB_INPUT_FILENAME");
        string memory outputFilename = vm.envString("HUB_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/spoke-machine-mailboxes/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "outputs/spoke-machine-mailboxes/");
        outputPath = string.concat(outputPath, outputFilename);

        // load output from DeployHubMachine script
        string memory machineOutputPath = string.concat(basePath, "outputs/hub-machines/");
        machineOutputPath = string.concat(machineOutputPath, outputFilename);
        machineOutputJson = vm.readFile(machineOutputPath);
    }

    function run() public {
        IMachine machine = IMachine(abi.decode(vm.parseJson(machineOutputJson, ".machine"), (address)));

        uint256[] memory spokeChainIds = abi.decode(vm.parseJson(inputJson, ".spokeChainIds"), (uint256[]));

        string memory obj = "spokeMachineMailboxes";
        string memory list;

        // Deploy Mailboxes
        vm.startBroadcast();
        for (uint256 i; i < spokeChainIds.length; i++) {
            address mailbox = machine.createSpokeMailbox(spokeChainIds[i]);
            deployedInstances.push(mailbox);
            list = vm.serializeAddress(obj, vm.toString(spokeChainIds[i]), mailbox);
        }
        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-spoke-machine-mailbox-output-file";
        vm.writeJson(vm.serializeString(key, obj, list), outputPath);
    }
}
