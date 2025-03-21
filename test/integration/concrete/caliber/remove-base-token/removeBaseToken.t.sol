// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract RemoveBaseToken_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.removeBaseToken(address(baseToken));
    }

    function test_RevertWhen_TokenIsAccountingToken() public {
        vm.expectRevert(ICaliber.AccountingToken.selector);
        vm.prank(dao);
        caliber.removeBaseToken(address(accountingToken));
    }

    function test_RevertWhen_NonExistingBaseToken() public {
        vm.expectRevert(ICaliber.BaseTokenDoesNotExist.selector);
        vm.prank(dao);
        caliber.removeBaseToken(address(baseToken));
    }

    function test_RevertGiven_NonZeroTokenBalance() public withTokenAsBT(address(baseToken)) {
        deal(address(baseToken), address(caliber), 1);

        vm.expectRevert(ICaliber.NonZeroBalance.selector);
        vm.prank(dao);
        caliber.removeBaseToken(address(baseToken));
    }

    function test_RemoveBaseToken() public withTokenAsBT(address(baseToken)) {
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.BaseTokenRemoved(address(baseToken));
        vm.prank(dao);
        caliber.removeBaseToken(address(baseToken));

        assertEq(caliber.isBaseToken(address(baseToken)), false);
        assertEq(caliber.getBaseTokensLength(), 1);
    }
}
