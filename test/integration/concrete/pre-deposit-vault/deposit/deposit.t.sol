// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {Errors} from "src/libraries/Errors.sol";

import {PreDepositVault_Integration_Concrete_Test} from "../PreDepositVault.t.sol";

contract Deposit_Integration_Concrete_Test is PreDepositVault_Integration_Concrete_Test {
    function test_RevertGiven_VaultMigrated() public migrated {
        vm.expectRevert(Errors.Migrated.selector);
        preDepositVault.deposit(0, address(0), 0);
    }

    function test_Deposit() public {
        _test_Deposit();
    }

    function test_RevertGiven_MaxDepositExceeded() public {
        uint256 inputAmount = 1e18;
        uint256 expectedShares = preDepositVault.previewDeposit(inputAmount);
        uint256 newShareLimit = expectedShares - 1;

        vm.prank(riskManager);
        preDepositVault.setShareLimit(newShareLimit);

        deal(address(accountingToken), address(this), inputAmount, true);

        accountingToken.approve(address(preDepositVault), inputAmount);
        vm.expectRevert(Errors.ExceededMaxDeposit.selector);
        preDepositVault.deposit(inputAmount, address(this), 0);
    }

    function test_RevertWhen_SlippageProtectionTriggered() public {
        _test_RevertWhen_SlippageProtectionTriggered();
    }

    function test_RevertWhen_CallerNotWhitelisted_WhitelistMode() public whitelistMode {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        preDepositVault.deposit(0, address(0), 0);
    }

    function test_RevertWhen_SlippageProtectionTriggered_WhitelistMode()
        public
        whitelistMode
        whitelistedUser(address(this))
    {
        _test_RevertWhen_SlippageProtectionTriggered();
    }

    function test_Deposit_WhitelistMode() public whitelistMode whitelistedUser(address(this)) {
        _test_Deposit();
    }

    function _test_RevertWhen_SlippageProtectionTriggered() internal {
        uint256 inputAmount = 1e18;
        uint256 expectedShares = preDepositVault.previewDeposit(inputAmount);

        deal(address(baseToken), address(this), inputAmount, true);

        baseToken.approve(address(preDepositVault), inputAmount);

        vm.expectRevert(Errors.SlippageProtection.selector);
        preDepositVault.deposit(inputAmount, address(this), expectedShares + 1);
    }

    function _test_Deposit() public {
        uint256 inputAmount = 1e18;
        uint256 expectedShares = preDepositVault.previewDeposit(inputAmount);

        deal(address(baseToken), address(this), inputAmount, true);

        baseToken.approve(address(preDepositVault), inputAmount);
        vm.expectEmit(true, true, false, true, address(preDepositVault));
        emit IPreDepositVault.Deposit(address(this), address(this), inputAmount, expectedShares);
        preDepositVault.deposit(inputAmount, address(this), 0);

        assertEq(baseToken.balanceOf(address(this)), 0);
        assertEq(baseToken.balanceOf(address(preDepositVault)), inputAmount);
        assertEq(IERC20(preDepositVault.shareToken()).balanceOf(address(this)), expectedShares);
        assertEq(preDepositVault.totalAssets(), inputAmount);
    }
}
