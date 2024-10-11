// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {BaseTest} from "./BaseTest.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ICaliber} from "../src/interfaces/ICaliber.sol";

contract CaliberTest is BaseTest {
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event PositionAdded(uint256 indexed id, bool indexed isBaseToken);

    address private baseToken1;
    address private baseToken2;

    function _setUp() public override {
        baseToken1 = makeAddr("BaseToken1");
        baseToken2 = makeAddr("BaseToken2");
    }

    function test_caliber_getters() public view {
        assertEq(caliber.hubMachine(), address(0));
        assertEq(caliber.mechanic(), mechanic);
        assertEq(caliber.oracleRegistry(), address(oracleRegistry));
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.isBaseToken(address(accountingToken)), true);
        assertEq(caliber.getPositionsLength(), 1);
    }

    function test_cannotAddBaseTokenWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.addBaseToken(baseToken1, 2);
    }

    function test_addBaseToken() public {
        uint256 posId = 2;

        vm.prank(dao);
        caliber.addBaseToken(baseToken1, posId);

        assertEq(caliber.isBaseToken(baseToken1), true);
        assertEq(caliber.getPositionsLength(), 2);
        assertEq(caliber.getPositionId(1), posId);
        assertEq(caliber.getPosition(posId).lastAccounted, 0);
        assertEq(caliber.getPosition(posId).value, 0);
        assertEq(caliber.getPosition(posId).isBaseToken, true);
    }

    function test_cannotAddBaseTokenWithSamePosIdTwice() public {
        vm.startPrank(dao);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(baseToken1, 1);

        caliber.addBaseToken(baseToken1, 2);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(baseToken1, 2);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(baseToken2, 2);
    }

    function test_cannotAddBaseTokenWithZeroId() public {
        vm.expectRevert(ICaliber.ZeroPositionID.selector);
        vm.prank(dao);
        caliber.addBaseToken(baseToken1, 0);
    }

    function test_cannotSetMechanicWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMechanic(address(0x0));
    }

    function test_setMechanic() public {
        address newMechanic = makeAddr("NewMechanic");
        vm.expectEmit(true, true, false, true, address(caliber));
        emit MechanicChanged(mechanic, newMechanic);
        vm.prank(dao);
        caliber.setMechanic(newMechanic);
        assertEq(caliber.mechanic(), newMechanic);
    }
}
