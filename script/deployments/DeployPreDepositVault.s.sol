// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IHubCoreFactory} from "../../src/interfaces/IHubCoreFactory.sol";
import {IPreDepositVault} from "../../src/interfaces/IPreDepositVault.sol";

import {Base} from "../../test/base/Base.sol";

contract DeployPreDepositVault is Base, Script {
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
        string memory inputPath = string.concat(basePath, "inputs/pre-deposit-vaults/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contracts
        outputPath = string.concat(basePath, "outputs/pre-deposit-vaults/");
        outputPath = string.concat(outputPath, outputFilename);

        // load output from DeployHubCore script
        string memory coreOutputPath = string.concat(basePath, "outputs/hub-cores/");
        coreOutputPath = string.concat(coreOutputPath, coreOutputFilename);
        coreOutputJson = vm.readFile(coreOutputPath);
    }

    function run() public {
        IPreDepositVault.PreDepositVaultInitParams memory pdvParams = abi.decode(
            vm.parseJson(inputJson, ".preDepositVaultInitParams"), (IPreDepositVault.PreDepositVaultInitParams)
        );
        address depositToken = vm.parseJsonAddress(inputJson, ".depositToken");
        address accountingToken = vm.parseJsonAddress(inputJson, ".accountingToken");
        string memory shareTokenName = vm.parseJsonString(inputJson, ".shareTokenName");
        string memory shareTokenSymbol = vm.parseJsonString(inputJson, ".shareTokenSymbol");
        bool setupAMFunctionRoles = vm.parseJsonBool(inputJson, ".setupAMFunctionRoles");

        IHubCoreFactory hubCoreFactory = IHubCoreFactory(vm.parseJsonAddress(coreOutputJson, ".HubCoreFactory"));

        // Deploy pre-deposit vault
        vm.startBroadcast();

        deployedInstance = hubCoreFactory.createPreDepositVault(
            IPreDepositVault.PreDepositVaultInitParams(
                pdvParams.initialShareLimit,
                pdvParams.initialWhitelistMode,
                pdvParams.initialRiskManager,
                pdvParams.initialAuthority
            ),
            depositToken,
            accountingToken,
            shareTokenName,
            shareTokenSymbol,
            setupAMFunctionRoles
        );

        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-pre-deposit-vault-output-file";
        vm.serializeAddress(key, "preDepositVault", deployedInstance);
    }
}
