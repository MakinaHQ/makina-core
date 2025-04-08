// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {StdCheats} from "forge-std/StdCheats.sol";

abstract contract DeployViaIr is StdCheats {
    function deployWeirollVMViaIR() public returns (address weirollVM) {
        weirollVM = deployCode("out-ir-based/WeirollVM.sol/WeirollVM.json");
    }

    function deployMockAcrossV3SpokePoolViaIR() public returns (address mockAcrossV3SpokePool) {
        mockAcrossV3SpokePool = deployCode("out-ir-based/MockAcrossV3SpokePool.sol/MockAcrossV3SpokePool.json");
    }
}
