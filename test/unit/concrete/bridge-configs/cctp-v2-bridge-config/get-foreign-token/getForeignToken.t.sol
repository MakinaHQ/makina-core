// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {CctpV2BridgeConfig_Unit_Concrete_Test} from "../CctpV2BridgeConfig.t.sol";

contract GetForeignToken_Unit_Concrete_Test is CctpV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_ForeignTokenNotRegistered() public {
        vm.expectRevert(Errors.CctpForeignTokenNotRegistered.selector);
        cctpV2BridgeConfig.getForeignToken(address(0), 0);

        vm.expectRevert(Errors.CctpForeignTokenNotRegistered.selector);
        cctpV2BridgeConfig.getForeignToken(address(2), 2);

        vm.expectRevert(Errors.CctpForeignTokenNotRegistered.selector);
        cctpV2BridgeConfig.getForeignToken(address(1), 1);

        // associate local token 1 with foreign token 2 on foreign chain 2
        vm.prank(dao);
        cctpV2BridgeConfig.setForeignToken(address(1), 2, address(2));

        vm.expectRevert(Errors.CctpForeignTokenNotRegistered.selector);
        cctpV2BridgeConfig.getForeignToken(address(2), 2);

        vm.expectRevert(Errors.CctpForeignTokenNotRegistered.selector);
        cctpV2BridgeConfig.getForeignToken(address(1), 1);
    }

    function test_GetForeignToken() public {
        vm.prank(dao);
        cctpV2BridgeConfig.setForeignToken(address(1), 2, address(2));

        assertEq(cctpV2BridgeConfig.getForeignToken(address(1), 2), address(2));
    }
}
