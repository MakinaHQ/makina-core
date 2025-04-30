// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberFactory} from "src/interfaces/ICaliberFactory.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {SortedParams} from "./utils/SortedParams.sol";

contract DeploySpokeCaliber is Script, SortedParams {
    using stdJson for string;

    string private coreOutputJson;

    string public inputJson;
    string public outputPath;

    address public deployedInstance;

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
        CaliberInitParamsSorted memory cParams =
            abi.decode(vm.parseJson(inputJson, ".caliberInitParams"), (CaliberInitParamsSorted));
        MakinaGovernableInitParamsSorted memory mgParams =
            abi.decode(vm.parseJson(inputJson, ".makinaGovernableInitParams"), (MakinaGovernableInitParamsSorted));
        address hubMachine = abi.decode(vm.parseJson(inputJson, ".hubMachine"), (address));

        ICaliberFactory caliberFactory =
            ICaliberFactory(abi.decode(vm.parseJson(coreOutputJson, ".CaliberFactory"), (address)));

        // Deploy caliber
        vm.startBroadcast();
        deployedInstance = caliberFactory.createCaliber(
            ICaliber.CaliberInitParams(
                cParams.accountingToken,
                cParams.initialPositionStaleThreshold,
                cParams.initialAllowedInstrRoot,
                cParams.initialTimelockDuration,
                cParams.initialMaxPositionIncreaseLossBps,
                cParams.initialMaxPositionDecreaseLossBps,
                cParams.initialMaxSwapLossBps,
                cParams.initialCooldownDuration,
                cParams.initialFlashLoanModule
            ),
            IMakinaGovernable.MakinaGovernableInitParams(
                mgParams.initialMechanic,
                mgParams.initialSecurityCouncil,
                mgParams.initialRiskManager,
                mgParams.initialRiskManagerTimelock,
                mgParams.initialAuthority
            ),
            hubMachine
        );
        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-spoke-caliber-output-file";
        vm.serializeAddress(key, "caliber", deployedInstance);
        vm.writeJson(
            vm.serializeAddress(key, "caliberMailbox", ICaliber(deployedInstance).hubMachineEndpoint()), outputPath
        );
    }
}
