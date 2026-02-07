// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ICaliber} from "../../src/interfaces/ICaliber.sol";
import {IMachine} from "../../src/interfaces/IMachine.sol";
import {IHubCoreFactory} from "../../src/interfaces/IHubCoreFactory.sol";
import {IMakinaGovernable} from "../../src/interfaces/IMakinaGovernable.sol";
import {SortedParams} from "./utils/SortedParams.sol";

import {Base} from "../../test/base/Base.sol";

contract DeployHubMachine is Base, Script, SortedParams {
    using stdJson for string;

    string private coreOutputJson;

    string public inputJson;
    string public outputPath;

    address public deployedInstance;

    constructor() {
        string memory inputFilename = vm.envString("HUB_STRAT_INPUT_FILENAME");
        string memory outputFilename = vm.envString("HUB_STRAT_OUTPUT_FILENAME");

        string memory coreOutputFilename = vm.envString("HUB_CORE_OUTPUT_FILENAME");

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
        coreOutputPath = string.concat(coreOutputPath, coreOutputFilename);
        coreOutputJson = vm.readFile(coreOutputPath);
    }

    function run() public {
        MachineInitParamsSorted memory mParams =
            abi.decode(vm.parseJson(inputJson, ".machineInitParams"), (MachineInitParamsSorted));
        CaliberInitParamsSorted memory cParams =
            abi.decode(vm.parseJson(inputJson, ".caliberInitParams"), (CaliberInitParamsSorted));
        MakinaGovernableInitParamsSorted memory mgParams =
            abi.decode(vm.parseJson(inputJson, ".makinaGovernableInitParams"), (MakinaGovernableInitParamsSorted));
        address accountingToken = abi.decode(vm.parseJson(inputJson, ".accountingToken"), (address));
        string memory shareTokenName = abi.decode(vm.parseJson(inputJson, ".shareTokenName"), (string));
        string memory shareTokenSymbol = abi.decode(vm.parseJson(inputJson, ".shareTokenSymbol"), (string));
        bytes32 salt = abi.decode(vm.parseJson(inputJson, ".salt"), (bytes32));

        IHubCoreFactory hubCoreFactory =
            IHubCoreFactory(abi.decode(vm.parseJson(coreOutputJson, ".HubCoreFactory"), (address)));

        // Deploy machine
        vm.startBroadcast();

        deployedInstance = hubCoreFactory.createMachine(
            IMachine.MachineInitParams(
                mParams.initialDepositor,
                mParams.initialRedeemer,
                mParams.initialFeeManager,
                mParams.initialCaliberStaleThreshold,
                mParams.initialMaxFixedFeeAccrualRate,
                mParams.initialMaxPerfFeeAccrualRate,
                mParams.initialFeeMintCooldown,
                mParams.initialShareLimit,
                mParams.initialMaxSharePriceChangeRate
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
                mgParams.initialAuthority,
                mgParams.initialRestrictedAccountingMode
            ),
            accountingToken,
            shareTokenName,
            shareTokenSymbol,
            salt
        );

        if (!vm.envOr("SKIP_AM_SETUP", false)) {
            _setupMachineAMFunctionRoles(mgParams.initialAuthority, deployedInstance);
            _setupCaliberAMFunctionRoles(mgParams.initialAuthority, IMachine(deployedInstance).hubCaliber());
        }

        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-hub-machine-output-file";
        vm.serializeAddress(key, "machine", deployedInstance);
        vm.writeJson(vm.serializeAddress(key, "hubCaliber", IMachine(deployedInstance).hubCaliber()), outputPath);
    }
}
