// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IHubCoreFactory} from "../../src/interfaces/IHubCoreFactory.sol";
import {IPreDepositVault} from "../../src/interfaces/IPreDepositVault.sol";
import {SortedParams} from "./utils/SortedParams.sol";

contract DeployPreDepositVault is Script, SortedParams {
    using stdJson for string;

    string private coreOutputJson;

    string public inputJson;
    string public outputPath;

    address public deployedInstance;

    constructor() {
        string memory inputFilename = vm.envString("HUB_INPUT_FILENAME");
        string memory outputFilename = vm.envString("HUB_OUTPUT_FILENAME");

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
        coreOutputPath = string.concat(coreOutputPath, outputFilename);
        coreOutputJson = vm.readFile(coreOutputPath);
    }

    function run() public {
        PreDepositVaultInitParamsSorted memory pdvParams =
            abi.decode(vm.parseJson(inputJson, ".preDepositVaultInitParams"), (PreDepositVaultInitParamsSorted));
        address depositToken = abi.decode(vm.parseJson(inputJson, ".depositToken"), (address));
        address accountingToken = abi.decode(vm.parseJson(inputJson, ".accountingToken"), (address));
        string memory shareTokenName = abi.decode(vm.parseJson(inputJson, ".shareTokenName"), (string));
        string memory shareTokenSymbol = abi.decode(vm.parseJson(inputJson, ".shareTokenSymbol"), (string));

        IHubCoreFactory hubCoreFactory =
            IHubCoreFactory(abi.decode(vm.parseJson(coreOutputJson, ".HubCoreFactory"), (address)));

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
            shareTokenSymbol
        );
        vm.stopBroadcast();

        // Write to file
        string memory key = "key-deploy-pre-deposit-vault-output-file";
        vm.serializeAddress(key, "preDepositVault", deployedInstance);
    }
}
