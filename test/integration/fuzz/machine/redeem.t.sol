// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {Machine} from "src/machine/Machine.sol";
import {Constants} from "src/libraries/Constants.sol";

import {Base_Hub_Test} from "test/base/Base.t.sol";

contract Redeem_Integration_Fuzz_Test is Base_Hub_Test {
    MockERC20 public accountingToken;
    Machine public machine;

    struct Data {
        uint256 atDecimals;
        uint256 assetsToDeposit;
        uint256 sharesToRedeem1;
        uint256 sharesToRedeem2;
        uint256 yield1;
        bool yieldDirection1;
        uint256 yield2;
        bool yieldDirection2;
    }

    function _fuzzTestSetupAfter(uint256 atDecimals) public {
        atDecimals =
            uint8(bound(atDecimals, Constants.MIN_ACCOUNTING_TOKEN_DECIMALS, Constants.MAX_ACCOUNTING_TOKEN_DECIMALS));

        accountingToken = new MockERC20("Accounting Token", "ACT", atDecimals);

        MockPriceFeed aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setFeedRoute(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine,) = _deployMachine(address(accountingToken), bytes32(0));
    }

    function testFuzz_Redeem(Data memory data) public {
        _fuzzTestSetupAfter(data.atDecimals);
        data.assetsToDeposit = bound(data.assetsToDeposit, 0, 1e30);

        IERC20 shareToken = IERC20(machine.shareToken());

        accountingToken.mint(machineDepositor, data.assetsToDeposit);

        // deposit
        vm.startPrank(machineDepositor);
        accountingToken.approve(address(machine), data.assetsToDeposit);
        uint256 mintedShares = machine.deposit(data.assetsToDeposit, machineRedeemer);
        vm.stopPrank();

        uint256 expectedTotalAssets = data.assetsToDeposit;
        uint256 redeemedShares = 0;
        uint256 withdrawnAssets = 0;

        data.sharesToRedeem1 = bound(data.sharesToRedeem1, 0, mintedShares);
        uint256 expectedAssets1 = machine.convertToAssets(data.sharesToRedeem1);

        // generate yield
        if (data.yieldDirection1) {
            data.yield1 = bound(data.yield1, 0, type(uint256).max - accountingToken.totalSupply());
            accountingToken.mint(address(machine), data.yield1);
            expectedTotalAssets += data.yield1;
        } else {
            data.yield1 = bound(data.yield1, 0, expectedTotalAssets);
            accountingToken.burn(address(machine), data.yield1);
            expectedTotalAssets -= data.yield1;
        }

        // try 1st redeem
        if (expectedAssets1 > expectedTotalAssets) {
            vm.expectRevert(
                abi.encodeWithSelector(IMachine.ExceededMaxWithdraw.selector, expectedAssets1, expectedTotalAssets)
            );
            vm.prank(machineRedeemer);
            machine.redeem(data.sharesToRedeem1, address(this));
        } else {
            vm.expectEmit(true, true, true, true, address(machine));
            emit IMachine.Redeem(machineRedeemer, address(this), expectedAssets1, data.sharesToRedeem1);
            vm.prank(machineRedeemer);
            uint256 receivedAssets1 = machine.redeem(data.sharesToRedeem1, address(this));
            assertEq(receivedAssets1, expectedAssets1);

            redeemedShares += data.sharesToRedeem1;
            withdrawnAssets += receivedAssets1;
            expectedTotalAssets -= receivedAssets1;

            assertEq(accountingToken.balanceOf(address(this)), withdrawnAssets);
            assertEq(shareToken.balanceOf(machineRedeemer), mintedShares - redeemedShares);
            assertEq(shareToken.totalSupply(), mintedShares - redeemedShares);
            assertEq(machine.lastTotalAum(), data.assetsToDeposit - withdrawnAssets);
        }
        assertEq(accountingToken.balanceOf(address(machine)), expectedTotalAssets);

        data.sharesToRedeem2 = bound(data.sharesToRedeem2, 0, mintedShares - data.sharesToRedeem1);
        uint256 expectedAssets2 = machine.convertToAssets(data.sharesToRedeem2);

        // generate yield
        if (data.yieldDirection2) {
            data.yield2 = bound(data.yield2, 0, type(uint256).max - accountingToken.totalSupply());
            accountingToken.mint(address(machine), data.yield2);
            expectedTotalAssets += data.yield2;
        } else {
            data.yield2 = bound(data.yield2, 0, expectedTotalAssets);
            accountingToken.burn(address(machine), data.yield2);
            expectedTotalAssets -= data.yield2;
        }

        // try 2nd redeem
        if (expectedAssets2 > expectedTotalAssets) {
            vm.expectRevert(
                abi.encodeWithSelector(IMachine.ExceededMaxWithdraw.selector, expectedAssets2, expectedTotalAssets)
            );
            vm.prank(machineRedeemer);
            machine.redeem(data.sharesToRedeem2, address(this));
        } else {
            vm.expectEmit(true, true, true, true, address(machine));
            emit IMachine.Redeem(machineRedeemer, address(this), expectedAssets2, data.sharesToRedeem2);
            vm.prank(machineRedeemer);
            uint256 receivedAssets2 = machine.redeem(data.sharesToRedeem2, address(this));
            assertEq(receivedAssets2, expectedAssets2);

            redeemedShares += data.sharesToRedeem2;
            withdrawnAssets += receivedAssets2;
            expectedTotalAssets -= expectedAssets2;

            assertEq(accountingToken.balanceOf(address(this)), withdrawnAssets);
            assertEq(shareToken.balanceOf(machineRedeemer), mintedShares - redeemedShares);
            assertEq(shareToken.totalSupply(), mintedShares - redeemedShares);
            assertEq(machine.lastTotalAum(), data.assetsToDeposit - withdrawnAssets);
        }
        assertEq(accountingToken.balanceOf(address(machine)), expectedTotalAssets);
    }
}
