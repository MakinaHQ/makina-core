// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/StdJson.sol";

import {ICaliberFactory} from "../src/interfaces/ICaliberFactory.sol";

import "../test/Base.sol";

contract DeploySpokeCalibers is Script {
    using stdJson for string;

    struct DeploymentParams {
        address accountingToken;
        uint256 accountingTokenPosId;
        bytes32 initialAllowedInstrRoot;
        uint256 initialMaxPositionIncreaseLossBps;
        uint256 initialMaxPositionDecreaseLossBps;
        uint256 initialMaxSwapLossBps;
        address initialMechanic;
        uint256 initialPositionStaleThreshold;
        uint256 initialTimelockDuration;
        address spokeMachineMailbox;
    }

    string public constantsFilename = vm.envString("SPOKE_CONSTANTS_FILENAME");
    string public outputFilename = vm.envString("SPOKE_OUTPUT_FILENAME");

    string public jsonConstants;
    string public jsonOutput;

    CaliberFactory public spokeCaliberFactory;

    address public accessManager;
    address public securityCouncil;

    address[] public deployedCalibers;

    function run() public {
        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/script/constants/");
        string memory path = string.concat(basePath, constantsFilename);

        // load in vars
        jsonConstants = vm.readFile(path);
        DeploymentParams[] memory _calibersToDeploy =
            abi.decode(vm.parseJson(jsonConstants, ".calibersToDeploy"), (DeploymentParams[]));
        securityCouncil = abi.decode(vm.parseJson(jsonConstants, ".securityCouncil"), (address));

        // Read output from DeploySpectraGovernance script
        path = string.concat(basePath, "output/DeployMakinaCore-Spoke-");
        path = string.concat(path, outputFilename);
        jsonOutput = vm.readFile(path);
        spokeCaliberFactory = CaliberFactory(abi.decode(vm.parseJson(jsonOutput, ".CaliberFactory"), (address)));
        accessManager = abi.decode(vm.parseJson(jsonOutput, ".AccessManager"), (address));

        vm.startBroadcast();

        // Deploy all calibers
        for (uint256 i; i < _calibersToDeploy.length; i++) {
            deployedCalibers.push(
                spokeCaliberFactory.deployCaliber(
                    ICaliberFactory.CaliberDeployParams(
                        _calibersToDeploy[i].spokeMachineMailbox,
                        _calibersToDeploy[i].accountingToken,
                        _calibersToDeploy[i].accountingTokenPosId,
                        _calibersToDeploy[i].initialPositionStaleThreshold,
                        _calibersToDeploy[i].initialAllowedInstrRoot,
                        _calibersToDeploy[i].initialTimelockDuration,
                        _calibersToDeploy[i].initialMaxPositionIncreaseLossBps,
                        _calibersToDeploy[i].initialMaxPositionDecreaseLossBps,
                        _calibersToDeploy[i].initialMaxSwapLossBps,
                        _calibersToDeploy[i].initialMechanic,
                        securityCouncil,
                        accessManager
                    )
                )
            );
        }
        vm.stopBroadcast();

        // Write to file
        path = string.concat(basePath, "output/DeploySpokeCalibers-");
        path = string.concat(path, outputFilename);
        string memory key = "key-deploy-spoke-calibers-output-file";
        vm.writeJson(vm.serializeAddress(key, "calibers", deployedCalibers), path);
    }
}
