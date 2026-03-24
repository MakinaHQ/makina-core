// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICctpV2BridgeConfig} from "src/interfaces/ICctpV2BridgeConfig.sol";
import {Errors} from "src/libraries/Errors.sol";

import {CctpV2BridgeConfig_Unit_Concrete_Test} from "../CctpV2BridgeConfig.t.sol";

contract SetForeignToken_Unit_Concrete_Test is CctpV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        cctpV2BridgeConfig.setForeignToken(address(0), 0, address(0));
    }

    function test_RevertWhen_ZeroTokenAddress() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroTokenAddress.selector));
        cctpV2BridgeConfig.setForeignToken(address(0), 1, address(1));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroTokenAddress.selector));
        cctpV2BridgeConfig.setForeignToken(address(0), 0, address(1));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroTokenAddress.selector));
        cctpV2BridgeConfig.setForeignToken(address(1), 1, address(0));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroTokenAddress.selector));
        cctpV2BridgeConfig.setForeignToken(address(1), 0, address(0));
    }

    function test_RevertWhen_ZeroChainId() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        cctpV2BridgeConfig.setForeignToken(address(1), 0, address(2));
    }

    function test_SetToken_DifferentAddresses() public {
        vm.expectEmit(true, true, true, false, address(cctpV2BridgeConfig));
        emit ICctpV2BridgeConfig.ForeignTokenRegistered(address(1), 2, address(2));
        vm.prank(dao);
        cctpV2BridgeConfig.setForeignToken(address(1), 2, address(2));

        assertEq(cctpV2BridgeConfig.getForeignToken(address(1), 2), address(2));

        vm.expectRevert(abi.encodeWithSelector(Errors.CctpForeignTokenNotRegistered.selector, address(2), 2));
        cctpV2BridgeConfig.getForeignToken(address(2), 2);
    }

    function test_SetToken_SameAddresses() public {
        vm.expectEmit(true, true, true, false, address(cctpV2BridgeConfig));
        emit ICctpV2BridgeConfig.ForeignTokenRegistered(address(1), 2, address(1));
        vm.prank(dao);
        cctpV2BridgeConfig.setForeignToken(address(1), 2, address(1));

        assertEq(cctpV2BridgeConfig.getForeignToken(address(1), 2), address(1));
    }

    function test_SetToken_ReassignForeignToken() public {
        vm.startPrank(dao);

        cctpV2BridgeConfig.setForeignToken(address(1), 2, address(1));

        vm.expectEmit(true, true, true, false, address(cctpV2BridgeConfig));
        emit ICctpV2BridgeConfig.ForeignTokenRegistered(address(1), 2, address(2));
        cctpV2BridgeConfig.setForeignToken(address(1), 2, address(2));

        assertEq(cctpV2BridgeConfig.getForeignToken(address(1), 2), address(2));
    }

    function test_SetToken_ReassignLocalToken() public {
        vm.startPrank(dao);

        cctpV2BridgeConfig.setForeignToken(address(1), 2, address(1));

        vm.expectEmit(true, true, true, false, address(cctpV2BridgeConfig));
        emit ICctpV2BridgeConfig.ForeignTokenRegistered(address(2), 2, address(1));
        cctpV2BridgeConfig.setForeignToken(address(2), 2, address(1));

        assertEq(cctpV2BridgeConfig.getForeignToken(address(2), 2), address(1));

        vm.expectRevert(abi.encodeWithSelector(Errors.CctpForeignTokenNotRegistered.selector, address(1), 2));
        cctpV2BridgeConfig.getForeignToken(address(1), 2);
    }
}
