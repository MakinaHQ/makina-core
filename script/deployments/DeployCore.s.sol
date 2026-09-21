// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

// solhint-disable gas-custom-errors, reason-string

import {Script} from "forge-std/Script.sol";

import {CreateXUtils} from "./utils/CreateXUtils.sol";

import {Base} from "../../test/base/Base.sol";

/// @notice Shared logic of the scripts deploying a core (hub or spoke) and running its registry and AccessManager
///         setup in a single broadcast.
/// @dev Concrete scripts implement `_coreSetup`, `_writeOutput`, `_recordDir` and `_loadFilenamesFromEnv`.
///      Deployments go through CreateX and are bound to the broadcasting address, see `_deployCode`.
///
/// Env vars (read by the concrete scripts, unless `setFilenames` was called):
///   <HUB|SPOKE>_CORE_INPUT_FILENAME  - core input file holding the deployment parameters
///   <HUB|SPOKE>_CORE_OUTPUT_FILENAME - core output file to write the deployed contract addresses to
///   SKIP_AM_SETUP (optional)         - if true, skips the AccessManager function roles and role grants setup,
///                                      leaving the deployer as sole admin (for staging deployments)
abstract contract DeployCore is Base, Script, CreateXUtils {
    string public inputJson;
    string public outputPath;

    AMRoleGrant public superAdminRoleGrant;
    AMRoleGrant[] public otherRoleGrants;
    PriceFeedRoute[] public priceFeedRoutes;
    TokenToRegister[] public tokensToRegister;
    SwapperData[] public swappersData;
    BridgeData[] public bridgesData;

    address public deployer;

    bool public skipAMSetup;

    /// @dev Test hook to set the input and output filenames explicitly, instead of having `run` resolve them from
    ///      the env vars. An empty output filename skips writing the output file.
    function setFilenames(string memory inputFilename, string memory outputFilename) public {
        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        inputJson = vm.readFile(string.concat(basePath, "inputs/", _recordDir(), "/", inputFilename));

        outputPath = bytes(outputFilename).length == 0
            ? ""
            : string.concat(basePath, "outputs/", _recordDir(), "/", outputFilename);
    }

    /// @dev Test hook: leaves the deployer as sole admin (restricted functions default to ADMIN_ROLE).
    function setSkipAMSetup(bool _skip) public {
        skipAMSetup = _skip;
    }

    function run() public {
        if (bytes(inputJson).length == 0) {
            _loadFilenamesFromEnv();
            skipAMSetup = vm.envOr("SKIP_AM_SETUP", false);
        }

        _parseInputs();

        vm.startBroadcast();

        (, deployer,) = vm.readCallers();

        _coreSetup();

        vm.stopBroadcast();

        if (bytes(outputPath).length != 0) {
            _writeOutput();
        }
    }

    function _coreSetup() internal virtual;

    function _writeOutput() internal virtual;

    /// @dev Directory name of this script's input and output records, under `inputs/` and `outputs/`.
    function _recordDir() internal pure virtual returns (string memory);

    /// @dev Calls `setFilenames` with this script's env vars.
    function _loadFilenamesFromEnv() internal virtual;

    function _parseInputs() internal virtual {
        superAdminRoleGrant = AMRoleGrant({
            roleId: 0,
            account: vm.parseJsonAddress(inputJson, ".superAdminRoleGrant.account"),
            executionDelay: uint32(vm.parseJsonUint(inputJson, ".superAdminRoleGrant.executionDelay"))
        });

        AMRoleGrant[] memory _otherRoleGrants = parseAMRoleGrants(inputJson, ".otherRoleGrants");
        for (uint256 i; i < _otherRoleGrants.length; ++i) {
            otherRoleGrants.push(_otherRoleGrants[i]);
        }

        PriceFeedRoute[] memory _priceFeedRoutes = parsePriceFeedRoutes(inputJson, ".priceFeedRoutes");
        for (uint256 i; i < _priceFeedRoutes.length; ++i) {
            priceFeedRoutes.push(_priceFeedRoutes[i]);
        }

        TokenToRegister[] memory _tokensToRegister = parseTokensToRegister(inputJson, ".foreignTokens");
        for (uint256 i; i < _tokensToRegister.length; ++i) {
            tokensToRegister.push(_tokensToRegister[i]);
        }

        SwapperData[] memory _swappersData = parseSwappersData(inputJson, ".swappersTargets");
        for (uint256 i; i < _swappersData.length; ++i) {
            swappersData.push(_swappersData[i]);
        }

        BridgeData[] memory _bridgesData = parseBridgesData(inputJson, ".bridgesTargets");
        for (uint256 i; i < _bridgesData.length; ++i) {
            bridgesData.push(_bridgesData[i]);
        }
    }

    /// @dev Deploys through CreateX at the deployer-bound address and asserts it. An occupied CREATE2 slot (zero salt
    ///      domain, used for implementations) is reused: that address is bound to the init code hash, so the code
    ///      there is this exact bytecode. An occupied CREATE3 slot reverts before broadcasting, with a readable error
    ///      instead of CreateX's opaque one.
    function _deployCode(bytes memory bytecode, bytes32 salt) internal virtual override returns (address deployed) {
        deployed = _computeCreateXAddress(bytecode, salt, deployer);

        if (deployed.code.length != 0) {
            if (salt == 0) {
                return deployed;
            }
            revert(string.concat("DeployCore: CREATE3 target already has code: ", vm.toString(deployed)));
        }

        require(_deployCodeCreateX(bytecode, salt, deployer) == deployed, "DeployCore: CreateX address mismatch");
    }
}
