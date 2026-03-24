// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {CctpV2BridgeConfig_Unit_Concrete_Test} from "../CctpV2BridgeConfig.t.sol";

contract GetCctpDomain_Unit_Concrete_Test is CctpV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_EvmChainIdNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 0));
        cctpV2BridgeConfig.getCctpDomain(0);

        vm.expectRevert(abi.encodeWithSelector(Errors.EvmChainIdNotRegistered.selector, 2));
        cctpV2BridgeConfig.getCctpDomain(2);
    }

    function test_GetCctpDomain() public {
        assertEq(cctpV2BridgeConfig.getCctpDomain(1), 0);

        vm.prank(dao);
        cctpV2BridgeConfig.setCctpDomain(2, 3);

        assertEq(cctpV2BridgeConfig.getCctpDomain(2), 3);
    }
}
