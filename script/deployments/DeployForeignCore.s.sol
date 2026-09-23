// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {DeployCore} from "./DeployCore.s.sol";

/// @notice Shared logic of the scripts deploying the core of a foreign instance, on a chain hosting a core of the
///         main instance. The chain-scoped contracts (AccessManager, OracleRegistry, TokenRegistry, WeirollVM, bridge
///         configs) are shared, the instance-scoped ones are deployed at salt domains discriminated by the foreign
///         instance's hub chain id. No setup is performed, see the `SetupForeign*Core` scripts.
abstract contract DeployForeignCore is DeployCore {
    UpgradeableBeacon[] internal _bridgeAdapterBeacons;

    /// @dev Bridges only, the rest is read by the setup script.
    function _parseInputs() internal override {
        BridgeData[] memory _bridgesData = parseBridgesData(inputJson, ".bridgesTargets");
        for (uint256 i; i < _bridgesData.length; ++i) {
            bridgesData.push(_bridgesData[i]);
        }
    }

    /// @dev No AccessManager setup, so no `SKIP_AM_SETUP`.
    function loadParamsFromEnv() public override {
        _loadFilenamesFromEnv();
    }

    function _sharedCore() internal view returns (SharedCore memory) {
        return readSharedCore(vm.parseJsonAddress(inputJson, ".mainCoreRegistry"), bridgesData);
    }

    /// @dev Adds the bridge adapter beacons, by bridge id, to the output object `key`.
    function _serializeBridgeAdapterBeacons(string memory key) internal returns (string memory) {
        string memory babKey = string.concat(key, "-bridge-adapter-beacons");
        string memory bridgeAdapterBeaconList;
        for (uint256 i; i < bridgesData.length; ++i) {
            bridgeAdapterBeaconList = vm.serializeAddress(
                babKey, vm.toString(uint256(bridgesData[i].bridgeId)), address(_bridgeAdapterBeacons[i])
            );
        }
        return vm.serializeString(key, "BridgeAdapterBeacons", bridgeAdapterBeaconList);
    }
}
