// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

// solhint-disable gas-custom-errors, reason-string

import {Script} from "forge-std/Script.sol";

import {CreateXUtils} from "./utils/CreateXUtils.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @notice Deploys an OpenZeppelin `TimelockController` through CreateX, at an address bound to the deployer and to
///         the constructor arguments. When additional cancellers are configured, the deployer is the temporary admin
///         granting them the CANCELLER_ROLE, and renounces the admin role in the same broadcast.
///
/// Env vars (unless `setFilenames` was called):
///   TIMELOCK_CONTROLLER_INPUT_FILENAME  - input file holding the timelock parameters
///                                         (under script/deployments/inputs/timelock-controllers/)
///   TIMELOCK_CONTROLLER_OUTPUT_FILENAME - file to write the timelock address to
///                                         (under script/deployments/outputs/timelock-controllers/)
contract DeployTimelockController is Script, CreateXUtils {
    string public inputJson;
    string public outputPath;

    address public deployer;

    address payable public deployedInstance;

    bytes32 public constant TIMELOCK_CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant TIMELOCK_ADMIN_ROLE = 0x00;

    /// @dev Test hook to set the input and output filenames explicitly, instead of having `run` resolve them from
    ///      the env vars. An empty output filename skips writing the output file.
    function setFilenames(string memory inputFilename, string memory outputFilename) public {
        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        inputJson = vm.readFile(string.concat(basePath, "inputs/timelock-controllers/", inputFilename));

        outputPath = bytes(outputFilename).length == 0
            ? ""
            : string.concat(basePath, "outputs/timelock-controllers/", outputFilename);
    }

    function run() public {
        if (bytes(inputJson).length == 0) {
            setFilenames(
                vm.envString("TIMELOCK_CONTROLLER_INPUT_FILENAME"), vm.envString("TIMELOCK_CONTROLLER_OUTPUT_FILENAME")
            );
        }

        uint256 initialMinDelay = vm.parseJsonUint(inputJson, ".initialMinDelay");
        address[] memory initialProposers = vm.parseJsonAddressArray(inputJson, ".initialProposers");
        address[] memory initialExecutors = vm.parseJsonAddressArray(inputJson, ".initialExecutors");
        address[] memory additionalCancellers = vm.parseJsonAddressArray(inputJson, ".additionalCancellers");

        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();

        address initialAdmin = additionalCancellers.length > 0 ? deployer : address(0);

        bytes memory constructorArgs = abi.encode(initialMinDelay, initialProposers, initialExecutors, initialAdmin);
        bytes memory bytecode = abi.encodePacked(type(TimelockController).creationCode, constructorArgs);
        bytes32 salt = keccak256(constructorArgs);

        // The salt derives from the constructor arguments, so a same-parameter timelock already exists at this slot
        address expected = _computeCreateXAddress(bytecode, salt, deployer);
        require(
            expected.code.length == 0,
            string.concat("DeployTimelockController: CREATE3 target already has code: ", vm.toString(expected))
        );

        deployedInstance = payable(_deployCodeCreateX(bytecode, salt, deployer));
        require(deployedInstance == expected, "DeployTimelockController: CreateX address mismatch");

        if (additionalCancellers.length > 0) {
            // Grant additional cancellers the CANCELLER_ROLE
            for (uint256 i; i < additionalCancellers.length; ++i) {
                TimelockController(deployedInstance).grantRole(TIMELOCK_CANCELLER_ROLE, additionalCancellers[i]);
            }
            // Renounce the admin role
            TimelockController(deployedInstance).renounceRole(TIMELOCK_ADMIN_ROLE, deployer);
        }

        vm.stopBroadcast();

        if (bytes(outputPath).length != 0) {
            string memory key = "key-deploy-timelock-controller-output-file";
            vm.writeJson(vm.serializeAddress(key, "timelockController", deployedInstance), outputPath);
        }
    }
}
