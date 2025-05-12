// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IHubCoreFactory} from "src/interfaces/IHubCoreFactory.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {SortedParams} from "./utils/SortedParams.sol";

contract DeployHubMachineFromPreDeposit is Script, SortedParams {
    using stdJson for string;

    string private coreOutputJson;

    string public inputJson;
    string public outputPath;

    address public preDepositVault;
    address public deployedInstance;

    constructor() {
        string memory inputFilename = vm.envString("HUB_INPUT_FILENAME");
        string memory outputFilename = vm.envString("HUB_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/pre-deposit-migrations/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "outputs/pre-deposit-migrations/");
        outputPath = string.concat(outputPath, outputFilename);

        // load output from DeployHubCore script
        string memory coreOutputPath = string.concat(basePath, "outputs/hub-cores/");
        coreOutputPath = string.concat(coreOutputPath, outputFilename);
        coreOutputJson = vm.readFile(coreOutputPath);

        preDepositVault = abi.decode(vm.parseJson(inputJson, ".preDepositVault"), (address));
    }

    function run() public {
        MachineInitParamsSorted memory mParams =
            abi.decode(vm.parseJson(inputJson, ".machineInitParams"), (MachineInitParamsSorted));
        CaliberInitParamsSorted memory cParams =
            abi.decode(vm.parseJson(inputJson, ".caliberInitParams"), (CaliberInitParamsSorted));
        MakinaGovernableInitParamsSorted memory mgParams =
            abi.decode(vm.parseJson(inputJson, ".makinaGovernableInitParams"), (MakinaGovernableInitParamsSorted));

        IHubCoreFactory hubCoreFactory =
            IHubCoreFactory(abi.decode(vm.parseJson(coreOutputJson, ".HubCoreFactory"), (address)));

        // Deploy pre-deposit vault
        vm.startBroadcast();
        deployedInstance = hubCoreFactory.createMachineFromPreDeposit(
            IMachine.MachineInitParams(
                mParams.initialDepositor,
                mParams.initialRedeemer,
                mParams.initialFeeManager,
                mParams.initialCaliberStaleThreshold,
                mParams.initialMaxFeeAccrualRate,
                mParams.initialFeeMintCooldown,
                mParams.initialShareLimit
            ),
            ICaliber.CaliberInitParams(
                cParams.initialPositionStaleThreshold,
                cParams.initialAllowedInstrRoot,
                cParams.initialTimelockDuration,
                cParams.initialMaxPositionIncreaseLossBps,
                cParams.initialMaxPositionDecreaseLossBps,
                cParams.initialMaxSwapLossBps,
                cParams.initialCooldownDuration
            ),
            IMakinaGovernable.MakinaGovernableInitParams(
                mgParams.initialMechanic,
                mgParams.initialSecurityCouncil,
                mgParams.initialRiskManager,
                mgParams.initialRiskManagerTimelock,
                mgParams.initialAuthority
            ),
            preDepositVault
        );
        vm.stopBroadcast();

        // Write to file
        string memory key = "key-migrate-pre-deposit-output-file";
        vm.serializeAddress(key, "machine", deployedInstance);
        vm.writeJson(vm.serializeAddress(key, "hubCaliber", IMachine(deployedInstance).hubCaliber()), outputPath);
    }
}
