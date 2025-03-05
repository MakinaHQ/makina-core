// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineFactory} from "src/interfaces/IMachineFactory.sol";

import {DeployInstance} from "./DeployInstance.s.sol";

contract DeployHubMachine is DeployInstance {
    using stdJson for string;

    struct MachineInitParamsSorted {
        address accountingToken;
        address depositor;
        bool depositorOnlyMode;
        uint256 hubCaliberAccountingTokenPosID;
        bytes32 hubCaliberAllowedInstrRoot;
        uint256 hubCaliberPosStaleThreshold;
        uint256 hubCaliberMaxSwapLossBps;
        uint256 hubCaliberMaxPositionIncreaseLossBps;
        uint256 hubCaliberMaxPositionDecreaseLossBps;
        uint256 hubCaliberTimelockDuration;
        address initialAuthority;
        uint256 initialCaliberStaleThreshold;
        address initialMechanic;
        address initialSecurityCouncil;
        uint256 initialShareLimit;
        string shareTokenName;
        string shareTokenSymbol;
    }

    constructor() {
        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/script/constants/");

        string memory paramsFilename = vm.envString("HUB_MACHINE_PARAMS_FILENAME");
        string memory outputFilename = vm.envString("HUB_MACHINE_OUTPUT_FILENAME");
        string memory coreOutputFilename = vm.envString("HUB_CORE_OUTPUT_FILENAME");

        // load in params
        string memory paramsPath = string.concat(basePath, "hub-machines-params/");
        paramsPath = string.concat(paramsPath, paramsFilename);
        paramsJson = vm.readFile(paramsPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "output/DeployHubMachine-");
        outputPath = string.concat(outputPath, outputFilename);

        // load in output from DeployMakinaCoreHub script
        string memory coreOutputPath = string.concat(basePath, "output/DeployMakinaCore-Hub-");
        coreOutputPath = string.concat(coreOutputPath, coreOutputFilename);
        coreOutputJson = vm.readFile(coreOutputPath);
    }

    function run() public {
        MachineInitParamsSorted memory initParams = abi.decode(vm.parseJson(paramsJson), (MachineInitParamsSorted));

        IMachineFactory machineFactory =
            IMachineFactory(abi.decode(vm.parseJson(coreOutputJson, ".MachineFactory"), (address)));

        // Deploy caliber
        vm.startBroadcast();
        deployedInstance = machineFactory.deployMachine(
            IMachine.MachineInitParams(
                initParams.accountingToken,
                initParams.initialMechanic,
                initParams.initialSecurityCouncil,
                initParams.initialAuthority,
                initParams.depositor,
                initParams.initialCaliberStaleThreshold,
                initParams.initialShareLimit,
                initParams.hubCaliberAccountingTokenPosID,
                initParams.hubCaliberPosStaleThreshold,
                initParams.hubCaliberAllowedInstrRoot,
                initParams.hubCaliberTimelockDuration,
                initParams.hubCaliberMaxPositionIncreaseLossBps,
                initParams.hubCaliberMaxPositionDecreaseLossBps,
                initParams.hubCaliberMaxSwapLossBps,
                initParams.depositorOnlyMode,
                initParams.shareTokenName,
                initParams.shareTokenSymbol
            )
        );
        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-hub-machine-output-file";
        vm.writeJson(vm.serializeAddress(key, "machine", deployedInstance), outputPath);
        vm.writeJson(
            vm.serializeAddress(key, "hubCaliberMailbox", IMachine(deployedInstance).hubCaliberMailbox()), outputPath
        );
        vm.writeJson(
            vm.serializeAddress(
                key, "hubCaliber", ICaliberMailbox(IMachine(deployedInstance).hubCaliberMailbox()).caliber()
            ),
            outputPath
        );
    }
}
