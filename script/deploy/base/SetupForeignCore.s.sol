// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {AMGovCalldata} from "../utils/AMGovCalldata.sol";

import {ICoreRegistry} from "../../../src/interfaces/ICoreRegistry.sol";
import {ISwapModule} from "../../../src/interfaces/ISwapModule.sol";
import {Roles} from "../../../src/libraries/Roles.sol";

import {Base} from "../../../test/base/Base.sol";

/// @notice Shared logic of the scripts wiring the core of a foreign instance: registry setters and swapper targets,
///         then AccessManager function roles and the core factory's ADMIN_ROLE grant.
/// @dev Every call requires ADMIN_ROLE on the shared AccessManager, so the list is one batch, submitted in order.
///
/// Modes, selected by the `VIEW_MODE` env var:
///   - Broadcast (default): sends the calls, from an account holding ADMIN_ROLE (staging deployments).
///   - View (`VIEW_MODE=true`): logs each call's target and calldata, alongside its `AccessManager.schedule`
///     wrapper, sends nothing.
///
/// Env vars (read by the concrete scripts, unless `setFilenames` was called):
///   <HUB|SPOKE>_CORE_INPUT_FILENAME  - input file of the foreign core deployment
///   <HUB|SPOKE>_CORE_OUTPUT_FILENAME - output file of the foreign core deployment
///   VIEW_MODE (optional)             - true for view mode, unset or false for broadcast mode
abstract contract SetupForeignCore is Base, Script, AMGovCalldata {
    string public inputJson;
    string public outputJson;

    bool public viewMode;

    /// @dev In execution order.
    Call[] public calls;

    /// @dev Test hook to set the input and output filenames explicitly, instead of having `run` resolve them from
    ///      the env vars.
    function setFilenames(string memory inputFilename, string memory outputFilename) public {
        string memory basePath = string.concat(vm.projectRoot(), "/script/deploy/");

        inputJson = vm.readFile(string.concat(basePath, "inputs/", _recordDir(), "/", inputFilename));
        outputJson = vm.readFile(string.concat(basePath, "outputs/", _recordDir(), "/", outputFilename));
    }

    function setViewMode(bool _viewMode) public {
        viewMode = _viewMode;
    }

    /// @dev Reads `VIEW_MODE` and calls `setFilenames` with this script's env vars.
    function loadParamsFromEnv() public {
        viewMode = vm.envOr("VIEW_MODE", false);
        _loadFilenamesFromEnv();
    }

    function run() public {
        if (bytes(inputJson).length == 0) {
            loadParamsFromEnv();
        }

        _buildCalls();

        if (viewMode) {
            for (uint256 i; i < calls.length; ++i) {
                _logCall(calls[i]);
            }
            return;
        }

        vm.startBroadcast();

        for (uint256 i; i < calls.length; ++i) {
            Address.functionCall(calls[i].target, calls[i].data);
        }

        vm.stopBroadcast();
    }

    function callsLength() public view returns (uint256) {
        return calls.length;
    }

    /// @dev Pushes the calls, in execution order.
    function _buildCalls() internal virtual;

    /// @dev Directory name of this script's input and output records, under `inputs/` and `outputs/`.
    function _recordDir() internal pure virtual returns (string memory);

    /// @dev Calls `setFilenames` with this script's env vars.
    function _loadFilenamesFromEnv() internal virtual;

    function _sharedCore(BridgeData[] memory bridgesData) internal view returns (SharedCore memory) {
        return readSharedCore(vm.parseJsonAddress(inputJson, ".mainCoreRegistry"), bridgesData);
    }

    /// @dev An address of the foreign core output file.
    function _deployed(string memory key) internal view returns (address) {
        return vm.parseJsonAddress(outputJson, string.concat(".", key));
    }

    function _deployedBridgeAdapterBeacon(uint16 bridgeId) internal view returns (address) {
        return vm.parseJsonAddress(outputJson, string.concat(".BridgeAdapterBeacons.", vm.toString(uint256(bridgeId))));
    }

    function _pushCall(string memory label, address target, bytes memory data) internal {
        calls.push(Call({label: label, target: target, data: data}));
    }

    /// @dev Adapter beacon and shared bridge config, per bridge.
    function _pushBridgeCalls(string memory registryName, address registry, SharedCore memory shared) internal {
        for (uint256 i; i < shared.bridgeIds.length; ++i) {
            uint16 bridgeId = shared.bridgeIds[i];
            string memory bridgeLabel = string.concat(", bridge id ", vm.toString(uint256(bridgeId)));
            _pushCall(
                string.concat(registryName, ".setBridgeAdapterBeacon", bridgeLabel),
                registry,
                abi.encodeCall(ICoreRegistry.setBridgeAdapterBeacon, (bridgeId, _deployedBridgeAdapterBeacon(bridgeId)))
            );
            _pushCall(
                string.concat(registryName, ".setBridgeConfig", bridgeLabel),
                registry,
                abi.encodeCall(ICoreRegistry.setBridgeConfig, (bridgeId, shared.bridgeConfigs[i]))
            );
        }
    }

    function _pushSwapperCalls(address swapModule, SwapperData[] memory swappersData) internal {
        for (uint256 i; i < swappersData.length; ++i) {
            _pushCall(
                string.concat(
                    "SwapModule.setSwapperTargets, swapper id ", vm.toString(uint256(swappersData[i].swapperId))
                ),
                swapModule,
                abi.encodeCall(
                    ISwapModule.setSwapperTargets,
                    (swappersData[i].swapperId, swappersData[i].approvalTarget, swappersData[i].executionTarget)
                )
            );
        }
    }

    function _pushSetTargetFunctionRole(
        address accessManager,
        string memory targetName,
        address target,
        bytes4[] memory selectors,
        uint64 roleId
    ) internal {
        _pushCall(
            string.concat("AccessManager.setTargetFunctionRole ", targetName),
            accessManager,
            abi.encodeCall(IAccessManager.setTargetFunctionRole, (target, selectors, roleId))
        );
    }

    function _pushProxyAdminRoles(
        address accessManager,
        string memory registryName,
        address registry,
        string memory factoryName,
        address factory,
        address swapModule
    ) internal {
        bytes4[] memory selectors = _proxyAdminAMSelectors();
        _pushSetTargetFunctionRole(
            accessManager,
            string.concat("ProxyAdmin of ", registryName),
            getProxyAdmin(registry),
            selectors,
            Roles.INFRA_UPGRADE_ROLE
        );
        _pushSetTargetFunctionRole(
            accessManager,
            string.concat("ProxyAdmin of ", factoryName),
            getProxyAdmin(factory),
            selectors,
            Roles.INFRA_UPGRADE_ROLE
        );
        _pushSetTargetFunctionRole(
            accessManager, "ProxyAdmin of SwapModule", getProxyAdmin(swapModule), selectors, Roles.INFRA_UPGRADE_ROLE
        );
    }

    function _pushBeaconRole(address accessManager, string memory beaconName, address beacon) internal {
        _pushSetTargetFunctionRole(accessManager, beaconName, beacon, _beaconAMSelectors(), Roles.INFRA_UPGRADE_ROLE);
    }

    function _pushBridgeAdapterBeaconRoles(address accessManager, uint16[] memory bridgeIds) internal {
        for (uint256 i; i < bridgeIds.length; ++i) {
            _pushBeaconRole(
                accessManager,
                string.concat("BridgeAdapterBeacon, bridge id ", vm.toString(uint256(bridgeIds[i]))),
                _deployedBridgeAdapterBeacon(bridgeIds[i])
            );
        }
    }

    /// @dev Required: the factory sets function roles on the components it creates.
    function _pushGrantAdminRole(address accessManager, string memory factoryName, address factory) internal {
        _pushCall(
            string.concat("AccessManager.grantRole ADMIN_ROLE to ", factoryName),
            accessManager,
            abi.encodeCall(IAccessManager.grantRole, (AccessManagerUpgradeable(accessManager).ADMIN_ROLE(), factory, 0))
        );
    }
}
