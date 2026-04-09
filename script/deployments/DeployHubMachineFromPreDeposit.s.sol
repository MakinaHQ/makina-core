// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "../../src/interfaces/ICaliber.sol";
import {IMachine} from "../../src/interfaces/IMachine.sol";
import {IHubCoreFactory} from "../../src/interfaces/IHubCoreFactory.sol";
import {IMakinaGovernable} from "../../src/interfaces/IMakinaGovernable.sol";

import {Base} from "../../test/base/Base.sol";

contract DeployHubMachineFromPreDeposit is Base, Script {
    using stdJson for string;

    string private coreOutputJson;

    string public inputJson;
    string public outputPath;

    address public preDepositVault;
    address public deployedInstance;

    constructor() {
        string memory inputFilename = vm.envString("HUB_STRAT_INPUT_FILENAME");
        string memory outputFilename = vm.envString("HUB_STRAT_OUTPUT_FILENAME");

        string memory coreOutputFilename = vm.envString("HUB_CORE_OUTPUT_FILENAME");

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
        coreOutputPath = string.concat(coreOutputPath, coreOutputFilename);
        coreOutputJson = vm.readFile(coreOutputPath);

        preDepositVault = vm.parseJsonAddress(inputJson, ".preDepositVault");
    }

    function run() public {
        IMachine.MachineInitParams memory mParams =
            abi.decode(vm.parseJson(inputJson, ".machineInitParams"), (IMachine.MachineInitParams));
        ICaliber.CaliberInitParams memory cParams =
            abi.decode(vm.parseJson(inputJson, ".caliberInitParams"), (ICaliber.CaliberInitParams));
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams = abi.decode(
            vm.parseJson(inputJson, ".makinaGovernableInitParams"), (IMakinaGovernable.MakinaGovernableInitParams)
        );
        IBridgeAdapterFactory.BridgeAdapterInitParams[] memory baParams = abi.decode(
            vm.parseJson(inputJson, ".bridgeAdapterInitParams"), (IBridgeAdapterFactory.BridgeAdapterInitParams[])
        );
        bytes32 salt = vm.parseJsonBytes32(inputJson, ".salt");
        bool setupAMFunctionRoles = vm.parseJsonBool(inputJson, ".setupAMFunctionRoles");

        IHubCoreFactory hubCoreFactory = IHubCoreFactory(vm.parseJsonAddress(coreOutputJson, ".HubCoreFactory"));

        // Deploy pre-deposit vault
        vm.startBroadcast();

        deployedInstance = hubCoreFactory.createMachineFromPreDeposit(
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
                cParams.initialCooldownDuration,
                cParams.initialBaseTokens
            ),
            IMakinaGovernable.MakinaGovernableInitParams(
                mgParams.initialMechanic,
                mgParams.initialSecurityCouncil,
                mgParams.initialRiskManager,
                mgParams.initialRiskManagerTimelock,
                mgParams.initialAuthority,
                mgParams.initialRestrictedAccountingMode,
                mgParams.initialAccountingAgents
            ),
            baParams,
            preDepositVault,
            salt,
            setupAMFunctionRoles
        );

        vm.stopBroadcast();

        // Write to file
        string memory key = "key-migrate-pre-deposit-output-file";
        vm.serializeAddress(key, "machine", deployedInstance);
        vm.writeJson(vm.serializeAddress(key, "hubCaliber", IMachine(deployedInstance).hubCaliber()), outputPath);
    }
}
