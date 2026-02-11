// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {Machine} from "src/machine/Machine.sol";
import {DecimalsUtils} from "src/libraries/DecimalsUtils.sol";

import {Base_Hub_Test} from "test/base/Base.t.sol";

contract Deposit_Integration_Fuzz_Test is Base_Hub_Test {
    MockERC20 internal accountingToken;
    Machine internal machine;

    function _fuzzTestSetupAfter(uint256 atDecimals) public {
        atDecimals = uint8(bound(atDecimals, DecimalsUtils.MIN_DECIMALS, DecimalsUtils.MAX_DECIMALS));

        accountingToken = new MockERC20("Accounting Token", "ACT", atDecimals);

        MockPriceFeed aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setFeedRoute(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine,) = _deployMachine(address(accountingToken), bytes32(0), TEST_DEPLOYMENT_SALT);
    }

    function testFuzz_Deposit(uint256 atDecimals, uint256 assets1, uint256 assets2, uint256 yield, bool yieldDirection)
        public
    {
        _fuzzTestSetupAfter(atDecimals);
        assets1 = bound(assets1, 0, 1e30);
        assets2 = bound(assets2, 0, 1e30);

        IERC20 shareToken = IERC20(machine.shareToken());

        deal(address(accountingToken), machineDepositor, assets1, true);

        vm.startPrank(machineDepositor);

        // 1st deposit
        uint256 expectedShares1 = machine.convertToShares(assets1);
        accountingToken.approve(address(machine), assets1);
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.Deposit(machineDepositor, address(this), assets1, expectedShares1, 0);
        machine.deposit(assets1, address(this), expectedShares1, 0);

        assertEq(accountingToken.balanceOf(address(this)), 0);
        assertEq(accountingToken.balanceOf(address(machine)), assets1);
        assertEq(shareToken.balanceOf(address(this)), expectedShares1);
        assertEq(shareToken.totalSupply(), expectedShares1);
        assertEq(machine.lastTotalAum(), assets1);

        uint256 expectedShares2 = machine.convertToShares(assets2);

        // generate yield
        if (yieldDirection) {
            yield = bound(yield, 0, type(uint256).max - assets1 - assets2);
            accountingToken.mint(address(machine), yield);
        } else {
            yield = bound(yield, 0, assets1);
            accountingToken.burn(address(machine), yield);
        }

        deal(address(accountingToken), machineDepositor, assets2, true);

        // 2nd deposit
        accountingToken.approve(address(machine), assets2);
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.Deposit(machineDepositor, address(this), assets2, expectedShares2, 0);
        machine.deposit(assets2, address(this), expectedShares2, 0);

        uint256 expectedTotalAssets = yieldDirection ? assets1 + assets2 + yield : assets1 + assets2 - yield;

        assertEq(accountingToken.balanceOf(address(this)), 0);
        assertEq(accountingToken.balanceOf(address(machine)), expectedTotalAssets);
        assertEq(shareToken.balanceOf(address(this)), expectedShares1 + expectedShares2);
        assertEq(shareToken.totalSupply(), expectedShares1 + expectedShares2);
        assertEq(machine.lastTotalAum(), assets1 + assets2);
    }
}
