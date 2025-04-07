// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineFactory} from "src/interfaces/IMachineFactory.sol";

contract DeployHubMachine is Script {
    using stdJson for string;

    string private coreOutputJson;

    string public inputJson;
    string public outputPath;

    address public deployedInstance;

    struct MachineInitParamsSorted {
        address accountingToken;
        bytes32 hubCaliberAllowedInstrRoot;
        address hubCaliberFlashLoanModule;
        uint256 hubCaliberMaxPositionDecreaseLossBps;
        uint256 hubCaliberMaxPositionIncreaseLossBps;
        uint256 hubCaliberMaxSwapLossBps;
        uint256 hubCaliberPosStaleThreshold;
        uint256 hubCaliberTimelockDuration;
        address initialAuthority;
        uint256 initialCaliberStaleThreshold;
        address initialDepositor;
        address initialMechanic;
        address initialRedeemer;
        address initialSecurityCouncil;
        uint256 initialShareLimit;
    }

    constructor() {
        string memory inputFilename = vm.envString("HUB_INPUT_FILENAME");
        string memory outputFilename = vm.envString("HUB_OUTPUT_FILENAME");

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
        coreOutputPath = string.concat(coreOutputPath, outputFilename);
        coreOutputJson = vm.readFile(coreOutputPath);
    }

    function run() public {
        MachineInitParamsSorted memory initParams =
            abi.decode(vm.parseJson(inputJson, ".machineInitParams"), (MachineInitParamsSorted));
        string memory shareTokenName = abi.decode(vm.parseJson(inputJson, ".shareTokenName"), (string));
        string memory shareTokenSymbol = abi.decode(vm.parseJson(inputJson, ".shareTokenSymbol"), (string));

        IMachineFactory machineFactory =
            IMachineFactory(abi.decode(vm.parseJson(coreOutputJson, ".MachineFactory"), (address)));

        // Deploy caliber
        vm.startBroadcast();
        deployedInstance = machineFactory.createMachine(
            IMachine.MachineInitParams(
                initParams.accountingToken,
                initParams.initialMechanic,
                initParams.initialSecurityCouncil,
                initParams.initialAuthority,
                initParams.initialDepositor,
                initParams.initialRedeemer,
                initParams.initialCaliberStaleThreshold,
                initParams.initialShareLimit,
                initParams.hubCaliberPosStaleThreshold,
                initParams.hubCaliberAllowedInstrRoot,
                initParams.hubCaliberTimelockDuration,
                initParams.hubCaliberMaxPositionIncreaseLossBps,
                initParams.hubCaliberMaxPositionDecreaseLossBps,
                initParams.hubCaliberMaxSwapLossBps,
                initParams.hubCaliberFlashLoanModule
            ),
            shareTokenName,
            shareTokenSymbol
        );
        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-hub-machine-output-file";
        vm.serializeAddress(key, "machine", deployedInstance);
        vm.writeJson(vm.serializeAddress(key, "hubCaliber", IMachine(deployedInstance).hubCaliber()), outputPath);
    }
}
