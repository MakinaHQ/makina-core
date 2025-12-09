// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Vm} from "forge-std/Vm.sol";

abstract contract IRCodeReader {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getWeirollVMCode() public view returns (bytes memory creationBytecode) {
        return vm.getCode("out-ir-based/WeirollVM.sol/WeirollVM.json");
    }

    function getMockAcrossV3SpokePoolCode() public view returns (bytes memory creationBytecode) {
        return vm.getCode("out-ir-based/MockAcrossV3SpokePool.sol/MockAcrossV3SpokePool.json");
    }

    function getMockLayerZeroEndpointV2Code() public view returns (bytes memory creationBytecode) {
        return vm.getCode("out-ir-based/MockLayerZeroEndpointV2.sol/MockLayerZeroEndpointV2.json");
    }
}
