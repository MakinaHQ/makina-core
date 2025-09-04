// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";

import {MachineUtils} from "../../src/libraries/MachineUtils.sol";

contract DeployHubLibs is Script {
    address constant CREATE2_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() public {
        vm.broadcast();
        (bool success,) = CREATE2_PROXY.call(abi.encodePacked(bytes32(0), type(MachineUtils).creationCode));
        require(success, "Failed to deploy MachineUtils");
    }
}
