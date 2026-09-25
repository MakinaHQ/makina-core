// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {DeployForeignCore} from "./base/DeployForeignCore.s.sol";

/// @notice Deploys the spoke core of a foreign instance, see `DeployForeignCore`.
///
/// Env vars (unless `setFilenames` was called):
///   SPOKE_CORE_INPUT_FILENAME  - input file holding the deployment parameters
///                                (under script/deploy/inputs/spoke-cores/)
///   SPOKE_CORE_OUTPUT_FILENAME - output file to write the deployed contract addresses to
///                                (under script/deploy/outputs/spoke-cores/)
contract DeployForeignSpokeCore is DeployForeignCore {
    SpokeCore private _core;

    function deployment() public view returns (SpokeCore memory, UpgradeableBeacon[] memory) {
        return (_core, _bridgeAdapterBeacons);
    }

    /// @dev `hubChainId` is both the CaliberMailbox immutable and the instance discriminator.
    function _coreSetup() internal override {
        uint256 hubChainId = vm.parseJsonUint(inputJson, ".hubChainId");
        require(hubChainId != 0 && hubChainId != block.chainid, "DeployForeignSpokeCore: invalid hubChainId");

        (_core, _bridgeAdapterBeacons) = deployForeignSpokeCore(_sharedCore(), hubChainId, bridgesData);
    }

    /// @dev Deployed contracts only, not the shared ones.
    function _writeOutput() internal override {
        string memory key = "key-deploy-makina-core-foreign-spoke-output-file";

        vm.serializeAddress(key, "SpokeCoreRegistry", address(_core.spokeCoreRegistry));
        vm.serializeAddress(key, "SpokeCoreFactory", address(_core.spokeCoreFactory));
        vm.serializeAddress(key, "SwapModule", address(_core.swapModule));
        vm.serializeAddress(key, "CaliberBeacon", address(_core.caliberBeacon));
        vm.serializeAddress(key, "CaliberMailboxBeacon", address(_core.caliberMailboxBeacon));
        vm.writeJson(_serializeBridgeAdapterBeacons(key), outputPath);
    }

    function _recordDir() internal pure override returns (string memory) {
        return "spoke-cores";
    }

    function _loadFilenamesFromEnv() internal override {
        setFilenames(vm.envString("SPOKE_CORE_INPUT_FILENAME"), vm.envString("SPOKE_CORE_OUTPUT_FILENAME"));
    }
}
