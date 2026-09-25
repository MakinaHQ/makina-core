// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {AMGovCalldata} from "../utils/AMGovCalldata.sol";

import {Base} from "../../../test/base/Base.sol";

/// @notice Shared logic of the scripts creating strategy components (machine, caliber, pre-deposit vault) through a
///         core factory.
/// @dev The factory `create*` functions are restricted: broadcast from an account holding the
///      STRATEGY_DEPLOYMENT_ROLE, or run in view mode to log the calldata for that account to submit.
///
/// Modes, selected by the `VIEW_MODE` env var:
///   - Broadcast (default): sends the call and writes the deployed addresses to the output file.
///   - View (`VIEW_MODE=true`): logs the factory address and the calldata, alongside its `AccessManager.schedule`
///     wrapper, sends nothing and writes no file.
///
/// Env vars (read by the concrete scripts, unless `setParams` was called):
///   <HUB|SPOKE>_CORE_OUTPUT_FILENAME  - core output file holding the core factory address
///   <HUB|SPOKE>_STRAT_INPUT_FILENAME  - strategy component init params input file
///   <HUB|SPOKE>_STRAT_OUTPUT_FILENAME - file to write the deployed addresses to (broadcast mode only)
///   VIEW_MODE (optional)              - true for view mode, unset or false for broadcast mode
abstract contract DeployInstance is Base, Script, AMGovCalldata {
    string public inputJson;
    string public outputPath;

    address public coreFactory;

    bool public viewMode;

    address public deployedInstance;

    /// @dev Test hook to set the core factory and the input/output filenames explicitly, instead of having `run`
    ///      resolve them from the env vars and the core output file. An empty output filename skips writing the
    ///      output file.
    function setParams(address _coreFactory, string memory inputFilename, string memory outputFilename) public {
        coreFactory = _coreFactory;

        string memory basePath = string.concat(vm.projectRoot(), "/script/deploy/");

        inputJson = vm.readFile(string.concat(basePath, "inputs/", _recordDir(), "/", inputFilename));

        outputPath = bytes(outputFilename).length == 0
            ? ""
            : string.concat(basePath, "outputs/", _recordDir(), "/", outputFilename);
    }

    function setViewMode(bool _viewMode) public {
        viewMode = _viewMode;
    }

    /// @dev Reads `VIEW_MODE` and calls `setParams` with this script's env vars.
    function loadParamsFromEnv() public {
        viewMode = vm.envOr("VIEW_MODE", false);
        _loadParamsFromEnv();
    }

    function run() public {
        if (bytes(inputJson).length == 0) {
            loadParamsFromEnv();
        }

        Call memory call = _createCall();

        if (viewMode) {
            _logCall(call);
            return;
        }

        vm.startBroadcast();

        deployedInstance = abi.decode(Address.functionCall(call.target, call.data), (address));

        vm.stopBroadcast();

        if (bytes(outputPath).length != 0) {
            _writeOutput();
        }
    }

    /// @dev The core factory call creating the strategy component, built from the input file.
    function _createCall() internal view virtual returns (Call memory);

    function _writeOutput() internal virtual;

    /// @dev Directory name of this script's input and output records, under `inputs/` and `outputs/`.
    function _recordDir() internal pure virtual returns (string memory);

    /// @dev Calls `setParams` with this script's env vars, `viewMode` being already set.
    function _loadParamsFromEnv() internal virtual;

    /// @dev Core factory address read from a core output record.
    function _coreFactoryFromRecord(string memory coreRecordDir, string memory coreOutputFilename, string memory key)
        internal
        view
        returns (address)
    {
        string memory recordPath =
            string.concat(vm.projectRoot(), "/script/deploy/outputs/", coreRecordDir, "/", coreOutputFilename);
        return vm.parseJsonAddress(vm.readFile(recordPath), key);
    }

    /// @dev The output filename is not needed in view mode, as no file is written.
    function _outputFilenameFromEnv(string memory envVar) internal view returns (string memory) {
        return viewMode ? "" : vm.envString(envVar);
    }
}
