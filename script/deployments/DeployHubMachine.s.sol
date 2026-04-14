// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "../../src/interfaces/ICaliber.sol";
import {IMachine} from "../../src/interfaces/IMachine.sol";
import {IHubCoreFactory} from "../../src/interfaces/IHubCoreFactory.sol";
import {IMakinaGovernable} from "../../src/interfaces/IMakinaGovernable.sol";

import {Base} from "../../test/base/Base.sol";

contract DeployHubMachine is Base, Script {
    using stdJson for string;

    string private coreOutputJson;

    string public inputJson;
    string public outputPath;

    address public deployedInstance;

    constructor() {
        string memory inputFilename = vm.envString("HUB_STRAT_INPUT_FILENAME");
        string memory outputFilename = vm.envString("HUB_STRAT_OUTPUT_FILENAME");

        string memory coreOutputFilename = vm.envString("HUB_CORE_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/hub-machines/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "outputs/hub-machines/");
        outputPath = string.concat(outputPath, outputFilename);

        // load output from DeployHubCore script
        string memory coreOutputPath = string.concat(basePath, "outputs/hub-cores/");
        coreOutputPath = string.concat(coreOutputPath, coreOutputFilename);
        coreOutputJson = vm.readFile(coreOutputPath);
    }

    function run() public {
        IMachine.MachineInitParams memory mParams = parseMachineInitParams(inputJson, ".machineInitParams");
        ICaliber.CaliberInitParams memory cParams = parseCaliberInitParams(inputJson, ".caliberInitParams");
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams =
            parseMakinaGovernableInitParams(inputJson, ".makinaGovernableInitParams");
        IBridgeAdapterFactory.BridgeAdapterInitParams[] memory baParams =
            parseBridgeAdaptersInitParams(inputJson, ".bridgeAdapterInitParams");
        address accountingToken = vm.parseJsonAddress(inputJson, ".accountingToken");
        string memory shareTokenName = vm.parseJsonString(inputJson, ".shareTokenName");
        string memory shareTokenSymbol = vm.parseJsonString(inputJson, ".shareTokenSymbol");
        bytes32 salt = vm.parseJsonBytes32(inputJson, ".salt");
        bool setupAMFunctionRoles = vm.parseJsonBool(inputJson, ".setupAMFunctionRoles");

        IHubCoreFactory hubCoreFactory = IHubCoreFactory(vm.parseJsonAddress(coreOutputJson, ".HubCoreFactory"));

        // Deploy machine
        vm.startBroadcast();

        deployedInstance = hubCoreFactory.createMachine(
            mParams,
            cParams,
            mgParams,
            baParams,
            accountingToken,
            shareTokenName,
            shareTokenSymbol,
            salt,
            setupAMFunctionRoles
        );

        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-hub-machine-output-file";
        vm.serializeAddress(key, "machine", deployedInstance);
        vm.writeJson(vm.serializeAddress(key, "hubCaliber", IMachine(deployedInstance).hubCaliber()), outputPath);
    }
}
