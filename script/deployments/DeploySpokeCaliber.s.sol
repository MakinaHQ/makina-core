// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberFactory} from "src/interfaces/ICaliberFactory.sol";

import {DeployInstance} from "./DeployInstance.s.sol";

contract DeploySpokeCaliber is DeployInstance {
    using stdJson for string;

    struct CaliberInitParamsSorted {
        address accountingToken;
        uint256 accountingTokenPosId;
        bytes32 initialAllowedInstrRoot;
        address initialAuthority;
        uint256 initialMaxPositionDecreaseLossBps;
        uint256 initialMaxPositionIncreaseLossBps;
        uint256 initialMaxSwapLossBps;
        address initialMechanic;
        uint256 initialPositionStaleThreshold;
        address initialSecurityCouncil;
        uint256 initialTimelockDuration;
        address spokeMachineMailbox;
    }

    constructor() {
        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/script/constants/");

        string memory paramsFilename = vm.envString("SPOKE_CALIBER_PARAMS_FILENAME");
        string memory outputFilename = vm.envString("SPOKE_CALIBER_OUTPUT_FILENAME");
        string memory coreOutputFilename = vm.envString("SPOKE_CORE_OUTPUT_FILENAME");

        // load in params
        string memory paramsPath = string.concat(basePath, "spoke-calibers-params/");
        paramsPath = string.concat(paramsPath, paramsFilename);
        paramsJson = vm.readFile(paramsPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "output/DeploySpokeCaliber-");
        outputPath = string.concat(outputPath, outputFilename);

        // load in output from DeployMakinaCoreSpoke script
        string memory coreOutputPath = string.concat(basePath, "output/DeployMakinaCore-Spoke-");
        coreOutputPath = string.concat(coreOutputPath, coreOutputFilename);
        coreOutputJson = vm.readFile(coreOutputPath);
    }

    function run() public {
        CaliberInitParamsSorted memory deployParams = abi.decode(vm.parseJson(paramsJson), (CaliberInitParamsSorted));

        ICaliberFactory caliberFactory =
            ICaliberFactory(abi.decode(vm.parseJson(coreOutputJson, ".CaliberFactory"), (address)));

        // Deploy caliber
        vm.startBroadcast();
        deployedInstance = caliberFactory.deployCaliber(
            ICaliberFactory.CaliberDeployParams(
                deployParams.spokeMachineMailbox,
                deployParams.accountingToken,
                deployParams.accountingTokenPosId,
                deployParams.initialPositionStaleThreshold,
                deployParams.initialAllowedInstrRoot,
                deployParams.initialTimelockDuration,
                deployParams.initialMaxPositionIncreaseLossBps,
                deployParams.initialMaxPositionDecreaseLossBps,
                deployParams.initialMaxSwapLossBps,
                deployParams.initialMechanic,
                deployParams.initialSecurityCouncil,
                deployParams.initialAuthority
            )
        );
        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-spoke-caliber-output-file";
        vm.writeJson(vm.serializeAddress(key, "caliber", deployedInstance), outputPath);
        vm.writeJson(vm.serializeAddress(key, "caliberMailbox", ICaliber(deployedInstance).mailbox()), outputPath);
    }
}
