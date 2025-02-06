// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract AddBaseToken_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.addBaseToken(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID);
    }

    function test_RevertWhen_AlreadyExistingBaseToken()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        vm.expectRevert(ICaliber.BaseTokenAlreadyExists.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID + 1);
    }

    function test_RevertWhen_PositionIdZero() public {
        vm.expectRevert(ICaliber.ZeroPositionId.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 0);
    }

    function test_RevertWhen_AlreadyExistingPosId() public {
        vm.startPrank(dao);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);

        caliber.addBaseToken(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID);

        MockERC20 baseToken2 = new MockERC20("Base Token 2", "BT2", 18);
        oracleRegistry.setTokenFeedData(
            address(baseToken2), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken2), HUB_CALIBER_BASE_TOKEN_1_POS_ID);
    }

    function test_RevertGiven_FeedDataNotRegistered() public {
        MockERC20 baseToken2;
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken2), HUB_CALIBER_BASE_TOKEN_1_POS_ID + 1);
    }

    function test_AddBaseToken() public {
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.PositionCreated(HUB_CALIBER_BASE_TOKEN_1_POS_ID);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID);

        assertEq(caliber.isBaseToken(address(baseToken)), true);
        assertEq(caliber.getPositionsLength(), 2);
        assertEq(caliber.getPositionId(1), HUB_CALIBER_BASE_TOKEN_1_POS_ID);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).isBaseToken, true);
    }
}
