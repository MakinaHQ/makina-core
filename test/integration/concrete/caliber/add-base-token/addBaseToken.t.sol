// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract AddBaseToken_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.addBaseToken(address(baseToken));
    }

    function test_RevertWhen_TokenAddressZero() public {
        vm.expectRevert(Errors.ZeroTokenAddress.selector);
        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(0));
    }

    function test_RevertWhen_AlreadyExistingPositionToken() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        vm.expectRevert(Errors.AlreadyPositionToken.selector);
        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(vault));
    }

    function test_RevertWhen_AlreadyExistingBaseToken() public withTokenAsBT(address(baseToken)) {
        vm.expectRevert(Errors.AlreadyBaseToken.selector);
        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(baseToken));
    }

    function test_RevertGiven_PriceFeedRouteNotRegistered() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(baseToken2)));
        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(baseToken2));
    }

    function test_AddBaseToken() public {
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.BaseTokenAdded(address(baseToken));
        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(baseToken));

        assertEq(caliber.isBaseToken(address(baseToken)), true);
        assertEq(caliber.getBaseTokensLength(), 2);
    }
}
