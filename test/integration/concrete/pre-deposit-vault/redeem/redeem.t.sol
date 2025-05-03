// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";

import {PreDepositVault_Integration_Concrete_Test} from "../PreDepositVault.t.sol";

contract Redeem_Integration_Concrete_Test is PreDepositVault_Integration_Concrete_Test {
    function test_RevertGiven_VaultMigrated() public migrated {
        vm.expectRevert(IPreDepositVault.Migrated.selector);
        preDepositVault.redeem(0, address(0), 0);
    }

    function test_RevertWhen_SlippageProtectionTriggered() public {
        _test_RevertWhen_SlippageProtectionTriggered();
    }

    function test_Redeem() public {
        _test_Redeem();
    }

    function test_RevertWhen_CallerNotWhitelisted_WhitelistMode() public whitelistMode {
        vm.expectRevert(IPreDepositVault.UnauthorizedCaller.selector);
        preDepositVault.redeem(0, address(0), 0);
    }

    function test_RevertWhen_SlippageProtectionTriggered_WhitelistMode()
        public
        whitelistMode
        whitelistedUser(address(this))
    {
        _test_RevertWhen_SlippageProtectionTriggered();
    }

    function test_Redeem_WhitelistMode() public whitelistMode whitelistedUser(address(this)) {
        _test_Redeem();
    }

    function _test_RevertWhen_SlippageProtectionTriggered() internal {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(this), inputAmount, true);

        // deposit assets
        baseToken.approve(address(preDepositVault), inputAmount);
        uint256 shares = preDepositVault.deposit(inputAmount, address(this), 0);
        vm.stopPrank();

        uint256 sharesToRedeem = shares / 3;
        uint256 expectedAssets = preDepositVault.previewRedeem(sharesToRedeem);

        vm.expectRevert(IPreDepositVault.SlippageProtection.selector);
        preDepositVault.redeem(sharesToRedeem, address(this), expectedAssets + 1);
    }

    function _test_Redeem() internal {
        uint256 inputAmount = 3e18;

        address receiver = makeAddr("receiver");

        deal(address(baseToken), address(this), inputAmount, true);

        // deposit assets
        baseToken.approve(address(preDepositVault), inputAmount);
        uint256 shares = preDepositVault.deposit(inputAmount, address(this), 0);
        vm.stopPrank();

        uint256 balAssetsReceiverBefore = baseToken.balanceOf(receiver);
        uint256 balAssetsVaultBefore = baseToken.balanceOf(address(preDepositVault));
        uint256 balSharesRedeemerBefore = IERC20(preDepositVault.shareToken()).balanceOf(address(this));

        // redeem partial shares
        uint256 sharesToRedeem = shares / 3;
        uint256 expectedAssets = preDepositVault.previewRedeem(sharesToRedeem);
        vm.expectEmit(true, true, false, true, address(preDepositVault));
        emit IPreDepositVault.Redeem(address(this), receiver, expectedAssets, sharesToRedeem);
        preDepositVault.redeem(sharesToRedeem, receiver, expectedAssets);

        uint256 balAssetsReceiverAfter = baseToken.balanceOf(receiver);
        uint256 balAssetsVaultAfter = baseToken.balanceOf(address(preDepositVault));
        uint256 balSharesRedeemerAfter = IERC20(preDepositVault.shareToken()).balanceOf(address(this));

        assertEq(balAssetsReceiverAfter - balAssetsReceiverBefore, expectedAssets);
        assertEq(balAssetsVaultBefore - balAssetsVaultAfter, expectedAssets);
        assertEq(balSharesRedeemerBefore - balSharesRedeemerAfter, sharesToRedeem);
        assertEq(preDepositVault.totalAssets(), balAssetsVaultAfter);

        balAssetsReceiverBefore = balAssetsReceiverAfter;
        balAssetsVaultBefore = balAssetsVaultAfter;
        balSharesRedeemerBefore = balSharesRedeemerAfter;

        // redeem remaining shares
        sharesToRedeem = balSharesRedeemerAfter;
        expectedAssets = preDepositVault.previewRedeem(sharesToRedeem);
        vm.expectEmit(true, true, false, true, address(preDepositVault));
        emit IPreDepositVault.Redeem(address(this), receiver, expectedAssets, sharesToRedeem);
        preDepositVault.redeem(sharesToRedeem, receiver, expectedAssets);

        balAssetsReceiverAfter = baseToken.balanceOf(receiver);
        balAssetsVaultAfter = baseToken.balanceOf(address(preDepositVault));
        balSharesRedeemerAfter = IERC20(preDepositVault.shareToken()).balanceOf(address(this));

        assertEq(balAssetsReceiverAfter - balAssetsReceiverBefore, expectedAssets);
        assertEq(balAssetsVaultBefore - balAssetsVaultAfter, expectedAssets);
        assertEq(balSharesRedeemerBefore - balSharesRedeemerAfter, sharesToRedeem);
        assertEq(preDepositVault.totalAssets(), balAssetsVaultAfter);
        assertEq(balAssetsVaultAfter, 0);
        assertEq(balSharesRedeemerAfter, 0);
    }
}
