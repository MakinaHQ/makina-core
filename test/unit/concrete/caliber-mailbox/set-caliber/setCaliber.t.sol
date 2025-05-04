// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {CaliberMailbox} from "src/caliber/CaliberMailbox.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";

import {Unit_Concrete_Spoke_Test} from "../../UnitConcrete.t.sol";

contract SetCaliber_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    CaliberMailbox public caliberMailbox2;

    function setUp() public override {
        Unit_Concrete_Spoke_Test.setUp();

        IMakinaGovernable.MakinaGovernableInitParams memory params;

        caliberMailbox2 = CaliberMailbox(
            address(
                new BeaconProxy(
                    address(caliberMailboxBeacon), abi.encodeCall(ICaliberMailbox.initialize, (params, address(0)))
                )
            )
        );
    }

    function test_RevertWhen_CallerNotFactory() public {
        vm.expectRevert(ICaliberMailbox.NotFactory.selector);
        caliberMailbox2.setCaliber(address(0));
    }

    function test_RevertGiven_CaliberAlreadySet() public {
        vm.prank(address(spokeCoreFactory));
        caliberMailbox2.setCaliber(address(1));

        vm.expectRevert(ICaliberMailbox.CaliberAlreadySet.selector);
        vm.prank(address(spokeCoreFactory));
        caliberMailbox2.setCaliber(address(1));

        vm.expectRevert(ICaliberMailbox.CaliberAlreadySet.selector);
        vm.prank(address(spokeCoreFactory));
        caliberMailbox2.setCaliber(address(2));
    }

    function test_SetCaliber() public {
        assertEq(caliberMailbox2.caliber(), address(0));

        vm.expectEmit(true, false, false, false, address(caliberMailbox2));
        emit ICaliberMailbox.CaliberSet(address(1));
        vm.prank(address(spokeCoreFactory));
        caliberMailbox2.setCaliber(address(1));

        assertEq(caliberMailbox2.caliber(), address(1));
    }
}
