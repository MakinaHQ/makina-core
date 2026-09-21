// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapterFactory} from "../../src/interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "../../src/interfaces/ICaliber.sol";
import {IMakinaGovernable} from "../../src/interfaces/IMakinaGovernable.sol";
import {ISpokeCoreFactory} from "../../src/interfaces/ISpokeCoreFactory.sol";

import {DeployInstance} from "./DeployInstance.s.sol";

/// @notice Builds the `SpokeCoreFactory.createCaliber` call for a new spoke caliber and its mailbox, then broadcasts
///         it or logs it. See `DeployInstance` for modes and env vars.
///
/// Env vars (unless `setParams` was called):
///   SPOKE_CORE_OUTPUT_FILENAME  - spoke core output file holding the SpokeCoreFactory address
///                                 (under script/deployments/outputs/spoke-cores/)
///   SPOKE_STRAT_INPUT_FILENAME  - caliber init params input file (under script/deployments/inputs/spoke-calibers/)
///   SPOKE_STRAT_OUTPUT_FILENAME - file to write the caliber and mailbox addresses to
///                                 (under script/deployments/outputs/spoke-calibers/, broadcast mode only)
///   VIEW_MODE (optional)        - true for view mode, unset or false for broadcast mode
contract DeploySpokeCaliber is DeployInstance {
    function _createCall() internal view override returns (Call memory) {
        ICaliber.CaliberInitParams memory cParams = parseCaliberInitParams(inputJson, ".caliberInitParams");
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams =
            parseMakinaGovernableInitParams(inputJson, ".makinaGovernableInitParams");
        IBridgeAdapterFactory.BridgeAdapterInitParams[] memory baParams =
            parseBridgeAdaptersInitParams(inputJson, ".bridgeAdapterInitParams");

        return Call({
            label: "SpokeCoreFactory.createCaliber",
            target: coreFactory,
            data: abi.encodeCall(
                ISpokeCoreFactory.createCaliber,
                (
                    cParams,
                    mgParams,
                    baParams,
                    vm.parseJsonAddress(inputJson, ".accountingToken"),
                    vm.parseJsonBytes32(inputJson, ".salt"),
                    vm.parseJsonBool(inputJson, ".setupAMFunctionRoles")
                )
            )
        });
    }

    function _writeOutput() internal override {
        string memory key = "key-deploy-spoke-caliber-output-file";
        vm.serializeAddress(key, "caliber", deployedInstance);
        vm.writeJson(
            vm.serializeAddress(key, "caliberMailbox", ICaliber(deployedInstance).hubMachineEndpoint()), outputPath
        );
    }

    function _recordDir() internal pure override returns (string memory) {
        return "spoke-calibers";
    }

    function _loadParamsFromEnv() internal override {
        setParams(
            _coreFactoryFromRecord("spoke-cores", vm.envString("SPOKE_CORE_OUTPUT_FILENAME"), ".SpokeCoreFactory"),
            vm.envString("SPOKE_STRAT_INPUT_FILENAME"),
            _outputFilenameFromEnv("SPOKE_STRAT_OUTPUT_FILENAME")
        );
    }
}
