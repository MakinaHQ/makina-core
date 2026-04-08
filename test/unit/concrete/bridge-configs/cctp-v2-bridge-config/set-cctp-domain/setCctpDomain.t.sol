// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICctpV2BridgeConfig} from "src/interfaces/ICctpV2BridgeConfig.sol";
import {Errors} from "src/libraries/Errors.sol";

import {CctpV2BridgeConfig_Unit_Concrete_Test} from "../CctpV2BridgeConfig.t.sol";

contract SetCctpDomain_Unit_Concrete_Test is CctpV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        cctpV2BridgeConfig.setCctpDomain(0, 0);
    }

    function test_RevertWhen_ZeroChainId() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
        vm.prank(dao);
        cctpV2BridgeConfig.setCctpDomain(0, 1);
    }

    function test_RevertWhen_ProtectedChainId() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(Errors.ProtectedChainId.selector));
        cctpV2BridgeConfig.setCctpDomain(1, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.ProtectedChainId.selector));
        cctpV2BridgeConfig.setCctpDomain(1, 1);
    }

    function test_RevertWhen_ProtectedCctpDomain() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ProtectedCctpDomain.selector));
        vm.prank(dao);
        cctpV2BridgeConfig.setCctpDomain(2, 0);
    }

    function test_SetCctpDomain_DifferentIds() public {
        vm.expectEmit(true, true, false, false, address(cctpV2BridgeConfig));
        emit ICctpV2BridgeConfig.CctpDomainRegistered(2, 3);
        vm.prank(dao);
        cctpV2BridgeConfig.setCctpDomain(2, 3);

        assertEq(cctpV2BridgeConfig.getCctpDomain(2), 3);

        vm.expectRevert(Errors.CctpDomainNotRegistered.selector);
        cctpV2BridgeConfig.getCctpDomain(3);
    }

    function test_SetCctpDomain_SameIds() public {
        vm.startPrank(dao);

        vm.expectEmit(true, true, false, false, address(cctpV2BridgeConfig));
        emit ICctpV2BridgeConfig.CctpDomainRegistered(2, 2);
        cctpV2BridgeConfig.setCctpDomain(2, 2);

        assertEq(cctpV2BridgeConfig.getCctpDomain(2), 2);
    }

    function test_SetCctpDomain_ReassignCctpDomain() public {
        vm.startPrank(dao);

        cctpV2BridgeConfig.setCctpDomain(2, 2);

        vm.expectEmit(true, true, false, false, address(cctpV2BridgeConfig));
        emit ICctpV2BridgeConfig.CctpDomainRegistered(2, 3);
        cctpV2BridgeConfig.setCctpDomain(2, 3);

        assertEq(cctpV2BridgeConfig.getCctpDomain(2), 3);

        vm.expectRevert(Errors.CctpDomainNotRegistered.selector);
        cctpV2BridgeConfig.getCctpDomain(3);
    }

    function test_SetCctpDomain_ReassignEvmChainId() public {
        vm.startPrank(dao);

        cctpV2BridgeConfig.setCctpDomain(2, 2);

        vm.expectEmit(true, true, false, false, address(cctpV2BridgeConfig));
        emit ICctpV2BridgeConfig.CctpDomainRegistered(3, 2);
        cctpV2BridgeConfig.setCctpDomain(3, 2);

        assertEq(cctpV2BridgeConfig.getCctpDomain(3), 2);

        vm.expectRevert(Errors.CctpDomainNotRegistered.selector);
        cctpV2BridgeConfig.getCctpDomain(2);
    }
}
