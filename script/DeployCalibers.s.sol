// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/StdJson.sol";
import "../test/Base.sol";

contract DeployCalibers is Script {
    using stdJson for string;

    struct CaliberDeploymentParams {
        address accountingToken;
        uint256 accountingTokenPosId;
        address hubMachineInbox;
        bytes32 initialAllowedInstrRoot;
        uint256 initialMaxMgmtLossBps;
        uint256 initialMaxSwapLossBps;
        address initialMechanic;
        uint256 initialPositionStaleThreshold;
        uint256 initialTimelockDuration;
    }

    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public outputFilename = vm.envString("OUTPUT_FILENAME");

    string public jsonConstants;
    string public jsonOutput;

    CaliberFactory public caliberFactory;

    address public accessManager;
    address public securityCouncil;

    address[] public deployedCalibers;

    function run() public {
        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/script/constants/");
        string memory path = string.concat(basePath, constantsFilename);

        // load in vars
        jsonConstants = vm.readFile(path);
        CaliberDeploymentParams[] memory _calibersToDeploy =
            abi.decode(vm.parseJson(jsonConstants, ".calibersToDeploy"), (CaliberDeploymentParams[]));
        securityCouncil = abi.decode(vm.parseJson(jsonConstants, ".securityCouncil"), (address));

        // Read output from DeploySpectraGovernance script
        path = string.concat(basePath, "output/DeployMakinaCore-");
        path = string.concat(path, outputFilename);
        jsonOutput = vm.readFile(path);
        caliberFactory = CaliberFactory(abi.decode(vm.parseJson(jsonOutput, ".CaliberFactory"), (address)));
        accessManager = abi.decode(vm.parseJson(jsonOutput, ".AccessManager"), (address));

        vm.startBroadcast();

        // Deploy all calibers
        for (uint256 i; i < _calibersToDeploy.length; i++) {
            deployedCalibers.push(
                caliberFactory.deployCaliber(
                    _calibersToDeploy[i].hubMachineInbox,
                    _calibersToDeploy[i].accountingToken,
                    _calibersToDeploy[i].accountingTokenPosId,
                    _calibersToDeploy[i].initialPositionStaleThreshold,
                    _calibersToDeploy[i].initialAllowedInstrRoot,
                    _calibersToDeploy[i].initialTimelockDuration,
                    _calibersToDeploy[i].initialMaxMgmtLossBps,
                    _calibersToDeploy[i].initialMaxSwapLossBps,
                    _calibersToDeploy[i].initialMechanic,
                    securityCouncil,
                    accessManager
                )
            );
        }
        vm.stopBroadcast();

        // Write to file
        path = string.concat(basePath, "output/DeployCalibers-");
        path = string.concat(path, outputFilename);
        string memory key = "key-deploy-calibers-output-file";
        vm.writeJson(vm.serializeAddress(key, "calibers", deployedCalibers), path);
    }
}
