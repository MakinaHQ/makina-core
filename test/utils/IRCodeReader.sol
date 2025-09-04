// SPDX-License-Identifier: Unlicense
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
}
