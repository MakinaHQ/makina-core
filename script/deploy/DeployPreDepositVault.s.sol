// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IHubCoreFactory} from "../../src/interfaces/IHubCoreFactory.sol";
import {IPreDepositVault} from "../../src/interfaces/IPreDepositVault.sol";

import {DeployInstance} from "./base/DeployInstance.s.sol";

/// @notice Builds the `HubCoreFactory.createPreDepositVault` call for a new pre-deposit vault, then broadcasts it or
///         logs it. See `DeployInstance` for modes and env vars.
///
/// Env vars (unless `setParams` was called):
///   HUB_CORE_OUTPUT_FILENAME  - hub core output file holding the HubCoreFactory address
///                               (under script/deploy/outputs/hub-cores/)
///   HUB_STRAT_INPUT_FILENAME  - pre-deposit vault init params input file
///                               (under script/deploy/inputs/pre-deposit-vaults/)
///   HUB_STRAT_OUTPUT_FILENAME - file to write the pre-deposit vault address to
///                               (under script/deploy/outputs/pre-deposit-vaults/, broadcast mode only)
///   VIEW_MODE (optional)      - true for view mode, unset or false for broadcast mode
contract DeployPreDepositVault is DeployInstance {
    function _createCall() internal view override returns (Call memory) {
        IPreDepositVault.PreDepositVaultInitParams memory pdvParams =
            parsePreDepositVaultInitParams(inputJson, ".preDepositVaultInitParams");

        return Call({
            label: "HubCoreFactory.createPreDepositVault",
            target: coreFactory,
            data: abi.encodeCall(
                IHubCoreFactory.createPreDepositVault,
                (
                    pdvParams,
                    vm.parseJsonAddress(inputJson, ".depositToken"),
                    vm.parseJsonAddress(inputJson, ".accountingToken"),
                    vm.parseJsonString(inputJson, ".shareTokenName"),
                    vm.parseJsonString(inputJson, ".shareTokenSymbol"),
                    vm.parseJsonBool(inputJson, ".setupAMFunctionRoles")
                )
            )
        });
    }

    function _writeOutput() internal override {
        string memory key = "key-deploy-pre-deposit-vault-output-file";
        vm.writeJson(vm.serializeAddress(key, "preDepositVault", deployedInstance), outputPath);
    }

    function _recordDir() internal pure override returns (string memory) {
        return "pre-deposit-vaults";
    }

    function _loadParamsFromEnv() internal override {
        setParams(
            _coreFactoryFromRecord("hub-cores", vm.envString("HUB_CORE_OUTPUT_FILENAME"), ".HubCoreFactory"),
            vm.envString("HUB_STRAT_INPUT_FILENAME"),
            _outputFilenameFromEnv("HUB_STRAT_OUTPUT_FILENAME")
        );
    }
}
