// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberFactory} from "src/interfaces/ICaliberFactory.sol";

contract DeploySpokeCaliber is Script {
    using stdJson for string;

    string private coreOutputJson;

    string public inputJson;
    string public outputPath;

    address public deployedInstance;

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
        string memory inputFilename = vm.envString("SPOKE_INPUT_FILENAME");
        string memory outputFilename = vm.envString("SPOKE_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/spoke-calibers/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "outputs/spoke-calibers/");
        outputPath = string.concat(outputPath, outputFilename);

        // load output from DeploySpokeCore script
        string memory coreOutputPath = string.concat(basePath, "outputs/spoke-cores/");
        coreOutputPath = string.concat(coreOutputPath, outputFilename);
        coreOutputJson = vm.readFile(coreOutputPath);
    }

    function run() public {
        CaliberInitParamsSorted memory deployParams = abi.decode(vm.parseJson(inputJson), (CaliberInitParamsSorted));

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
        vm.serializeAddress(key, "caliber", deployedInstance);
        vm.writeJson(vm.serializeAddress(key, "caliberMailbox", ICaliber(deployedInstance).mailbox()), outputPath);
    }
}
