// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {CreateXUtils} from "./utils/CreateXUtils.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {SortedParams} from "./utils/SortedParams.sol";

contract DeployTimelockController is Script, SortedParams, CreateXUtils {
    using stdJson for string;

    string public inputJson;
    string public outputPath;

    address public deployer;

    address payable public deployedInstance;

    bytes32 public constant TIMELOCK_CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant TIMELOCK_ADMIN_ROLE = 0x00;

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
        TimelockControllerInitParamsSorted memory tcParams =
            abi.decode(vm.parseJson(inputJson, ".timelockControllerInitParams"), (TimelockControllerInitParamsSorted));

        address[] memory additionalCancellers =
            abi.decode(vm.parseJson(inputJson, ".additionalCancellers"), (address[]));

        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();

        address initialAdmin = additionalCancellers.length > 0 ? deployer : address(0);

        bytes memory constructorArgs =
            abi.encode(tcParams.initialMinDelay, tcParams.initialProposers, tcParams.initialExecutors, initialAdmin);
        bytes32 salt = keccak256(constructorArgs);

        deployedInstance = payable(
            _deployCodeCreateX(abi.encodePacked(type(TimelockController).creationCode, constructorArgs), salt, deployer)
        );

        if (additionalCancellers.length > 0) {
            // Grant additional cancellers the CANCELLER_ROLE
            for (uint256 i; i < additionalCancellers.length; i++) {
                TimelockController(deployedInstance).grantRole(TIMELOCK_CANCELLER_ROLE, additionalCancellers[i]);
            }
            // Renounce the admin role
            TimelockController(deployedInstance).renounceRole(TIMELOCK_ADMIN_ROLE, deployer);
        }

        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-timelock-controller-output-file";
        vm.writeJson(vm.serializeAddress(key, "timelockController", deployedInstance), outputPath);
    }
}
