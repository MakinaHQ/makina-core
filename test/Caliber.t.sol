// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./BaseTest.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ICaliber} from "../src/interfaces/ICaliber.sol";
import {IOracleRegistry} from "../src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract CaliberTest is BaseTest {
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event PositionAdded(uint256 indexed id, bool indexed isBaseToken);

    MockERC20 private baseToken;

    MockPriceFeed private b1PriceFeed1;
    MockPriceFeed private aPriceFeed1;

    /// @dev A is the accounting token, B is the base token
    /// and E is the reference currency of the oracle registry
    uint256 private constant PRICE_A_E = 150;
    uint256 private constant PRICE_B_E = 60000;
    uint256 private constant PRICE_B_A = 400;

    function _setUp() public override {
        baseToken = new MockERC20("Base Token", "BT", 18);

        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);
        b1PriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_E * 1e18), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(accountingToken), address(aPriceFeed1), address(0));
        oracleRegistry.setTokenFeedData(address(baseToken), address(b1PriceFeed1), address(0));
        vm.stopPrank();

        caliber = _deployCaliber(address(accountingToken), accountingTokenPosID);
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
        caliber.addBaseToken(address(baseToken), 2);
    }

    function test_addBaseToken() public {
        uint256 posId = 2;

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), posId);

        assertEq(caliber.isBaseToken(address(baseToken)), true);
        assertEq(caliber.getPositionsLength(), 2);
        assertEq(caliber.getPositionId(1), posId);
        assertEq(caliber.getPosition(posId).lastAccountingTime, 0);
        assertEq(caliber.getPosition(posId).value, 0);
        assertEq(caliber.getPosition(posId).isBaseToken, true);
    }

    function test_cannotAddBaseTokenWithSamePosIdTwice() public {
        vm.startPrank(dao);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken), 1);

        caliber.addBaseToken(address(baseToken), 2);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken), 2);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken), 2);
    }

    function test_cannotAddBaseTokenWithZeroId() public {
        vm.expectRevert(ICaliber.ZeroPositionID.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 0);
    }

    function test_cannotAddBaseTokenWithoutRegisteredFeed() public {
        MockERC20 baseToken2;
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken2), 3);
    }

    function test_accountForATPosition() public {
        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, 0);

        caliber.accountForBaseToken(1);

        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, block.timestamp);

        deal(address(accountingToken), address(caliber), 1e18, true);

        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, block.timestamp);

        caliber.accountForBaseToken(1);

        assertEq(caliber.getPosition(1).value, 1e18);
        assertEq(caliber.getPosition(1).lastAccountingTime, block.timestamp);
    }

    function test_accountForBTPosition() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, 0);

        caliber.accountForBaseToken(2);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, block.timestamp);

        deal(address(baseToken), address(caliber), 1e18, true);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, block.timestamp);

        caliber.accountForBaseToken(2);

        assertEq(caliber.getPosition(2).value, 1e18 * PRICE_B_A);
        assertEq(caliber.getPosition(2).lastAccountingTime, block.timestamp);

        uint256 newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        deal(address(baseToken), address(caliber), 3e18, true);
        deal(address(accountingToken), address(caliber), 10e18, true);

        caliber.accountForBaseToken(2);

        assertEq(caliber.getPosition(2).value, 3e18 * PRICE_B_A);
        assertEq(caliber.getPosition(2).lastAccountingTime, newTimestamp);
    }

    function test_cannotAccountForUnexistingBTPosition() public {
        vm.prank(dao);

        vm.expectRevert(ICaliber.NotBaseTokenPosition.selector);
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
