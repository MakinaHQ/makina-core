// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract RemoveBaseToken_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.removeBaseToken(address(baseToken));
    }

    function test_RevertWhen_TokenIsAccountingToken() public {
        vm.expectRevert(Errors.AccountingToken.selector);
        vm.prank(riskManagerTimelock);
        caliber.removeBaseToken(address(accountingToken));
    }

    function test_RevertWhen_NonExistingBaseToken() public {
        vm.expectRevert(Errors.NotBaseToken.selector);
        vm.prank(riskManagerTimelock);
        caliber.removeBaseToken(address(baseToken));
    }

    function test_RevertGiven_NonZeroTokenBalance() public withTokenAsBT(address(baseToken)) {
        deal(address(baseToken), address(caliber), 1);

        vm.expectRevert(Errors.NonZeroBalance.selector);
        vm.prank(riskManagerTimelock);
        caliber.removeBaseToken(address(baseToken));
    }

    function test_RemoveBaseToken() public withTokenAsBT(address(baseToken)) {
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.BaseTokenRemoved(address(baseToken));
        vm.prank(riskManagerTimelock);
        caliber.removeBaseToken(address(baseToken));

        assertEq(caliber.isBaseToken(address(baseToken)), false);
        assertEq(caliber.getBaseTokensLength(), 1);
    }
}
