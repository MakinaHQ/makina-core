// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapterFactory} from "../../src/interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "../../src/interfaces/ICaliber.sol";
import {IHubCoreFactory} from "../../src/interfaces/IHubCoreFactory.sol";
import {IMachine} from "../../src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "../../src/interfaces/IMakinaGovernable.sol";
import {ISpokeSnapshotConsumer} from "../../src/interfaces/ISpokeSnapshotConsumer.sol";

import {DeployInstance} from "./base/DeployInstance.s.sol";

/// @notice Builds the `HubCoreFactory.createMachine` call for a new machine and its hub caliber, then broadcasts it
///         or logs it. See `DeployInstance` for modes and env vars.
///
/// Env vars (unless `setParams` was called):
///   HUB_CORE_OUTPUT_FILENAME  - hub core output file holding the HubCoreFactory address
///                               (under script/deploy/outputs/hub-cores/)
///   HUB_STRAT_INPUT_FILENAME  - machine init params input file (under script/deploy/inputs/hub-machines/)
///   HUB_STRAT_OUTPUT_FILENAME - file to write the machine and hub caliber addresses to
///                               (under script/deploy/outputs/hub-machines/, broadcast mode only)
///   VIEW_MODE (optional)      - true for view mode, unset or false for broadcast mode
contract DeployHubMachine is DeployInstance {
    function _createCall() internal view override returns (Call memory) {
        IMachine.MachineInitParams memory mParams = parseMachineInitParams(inputJson, ".machineInitParams");
        ICaliber.CaliberInitParams memory cParams = parseCaliberInitParams(inputJson, ".caliberInitParams");
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams =
            parseMakinaGovernableInitParams(inputJson, ".makinaGovernableInitParams");
        ISpokeSnapshotConsumer.SpokeSnapshotConsumerInitParams memory sscParams =
            parseSpokeSnapshotConsumerInitParams(inputJson, ".spokeSnapshotConsumerInitParams");
        IBridgeAdapterFactory.BridgeAdapterInitParams[] memory baParams =
            parseBridgeAdaptersInitParams(inputJson, ".bridgeAdapterInitParams");

        return Call({
            label: "HubCoreFactory.createMachine",
            target: coreFactory,
            data: abi.encodeCall(
                IHubCoreFactory.createMachine,
                (
                    mParams,
                    cParams,
                    mgParams,
                    sscParams,
                    baParams,
                    vm.parseJsonAddress(inputJson, ".accountingToken"),
                    vm.parseJsonString(inputJson, ".shareTokenName"),
                    vm.parseJsonString(inputJson, ".shareTokenSymbol"),
                    vm.parseJsonBytes32(inputJson, ".salt"),
                    vm.parseJsonBool(inputJson, ".setupAMFunctionRoles")
                )
            )
        });
    }

    function _writeOutput() internal override {
        string memory key = "key-deploy-hub-machine-output-file";
        vm.serializeAddress(key, "machine", deployedInstance);
        vm.writeJson(vm.serializeAddress(key, "hubCaliber", IMachine(deployedInstance).hubCaliber()), outputPath);
    }

    function _recordDir() internal pure override returns (string memory) {
        return "hub-machines";
    }

    function _loadParamsFromEnv() internal override {
        setParams(
            _coreFactoryFromRecord("hub-cores", vm.envString("HUB_CORE_OUTPUT_FILENAME"), ".HubCoreFactory"),
            vm.envString("HUB_STRAT_INPUT_FILENAME"),
            _outputFilenameFromEnv("HUB_STRAT_OUTPUT_FILENAME")
        );
    }
}
