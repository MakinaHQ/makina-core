// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {BaseTest} from "./BaseTest.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ICaliber} from "../src/interfaces/ICaliber.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract CaliberTest is BaseTest {
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event PositionAdded(uint256 indexed id, bool indexed isBaseToken);

    MockERC20 private baseToken1;
    MockERC20 private baseToken2;

    MockPriceFeed private priceFeed1;
    MockPriceFeed private priceFeed2;

    function _setUp() public override {
        baseToken1 = new MockERC20("BaseToken1", "BT1", 18);
        baseToken2 = new MockERC20("BaseToken2", "BT2", 18);

        priceFeed1 = new MockPriceFeed(18, 1e18);
        priceFeed2 = new MockPriceFeed(18, 1e18);

        vm.startPrank(dao);
        oracleRegistry.setPriceFeed(address(baseToken1), address(accountingToken), address(priceFeed1));
        oracleRegistry.setPriceFeed(address(baseToken2), address(accountingToken), address(priceFeed2));
        vm.stopPrank();
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
        caliber.addBaseToken(address(baseToken1), 2);
    }

    function test_addBaseToken() public {
        uint256 posId = 2;

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken1), posId);

        assertEq(caliber.isBaseToken(address(baseToken1)), true);
        assertEq(caliber.getPositionsLength(), 2);
        assertEq(caliber.getPositionId(1), posId);
        assertEq(caliber.getPosition(posId).lastAccountingTime, 0);
        assertEq(caliber.getPosition(posId).value, 0);
        assertEq(caliber.getPosition(posId).isBaseToken, true);
    }

    function test_cannotAddBaseTokenWithSamePosIdTwice() public {
        vm.startPrank(dao);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken1), 1);

        caliber.addBaseToken(address(baseToken1), 2);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken1), 2);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken1), 2);
    }

    function test_cannotAddBaseTokenWithZeroId() public {
        vm.expectRevert(ICaliber.ZeroPositionID.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken1), 0);
    }

    function test_accountForATPosition() public {
        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, 0);

        deal(address(accountingToken), address(caliber), 1e18, true);

        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, 0);

        caliber.accountForBaseToken(1);

        assertEq(caliber.getPosition(1).value, 1e18);
        assertEq(caliber.getPosition(1).lastAccountingTime, block.timestamp);
    }

    function test_accountForBTPosition() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken1), 2);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, 0);

        deal(address(baseToken1), address(caliber), 1e18, true);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, 0);

        caliber.accountForBaseToken(2);

        assertEq(caliber.getPosition(2).value, 1e18);
        assertEq(caliber.getPosition(2).lastAccountingTime, block.timestamp);

        uint256 newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        deal(address(baseToken1), address(caliber), 3e18, true);
        deal(address(accountingToken), address(caliber), 10e18, true);

        caliber.accountForBaseToken(2);

        assertEq(caliber.getPosition(2).value, 3e18);
        assertEq(caliber.getPosition(2).lastAccountingTime, newTimestamp);
    }

    function test_cannotAccountForUnexistingBTPosition() public {
        vm.prank(dao);

        vm.expectRevert(ICaliber.NotBaseTokenPosition.selector);
        caliber.accountForBaseToken(2);
    }

    function test_cannotAccountForPositiveBTPositionWithNegPrice() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken1), 2);

        priceFeed1.setLatestAnswer(-1e18);

        caliber.accountForBaseToken(2);
        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, block.timestamp);

        deal(address(baseToken1), address(caliber), 1e18, true);

        vm.expectRevert(ICaliber.NegativeTokenPrice.selector);
        caliber.accountForBaseToken(2);
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
