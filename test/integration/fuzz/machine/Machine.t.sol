// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {Constants} from "src/libraries/Constants.sol";

import {Base_Test} from "test/BaseTest.sol";

contract Machine_Integration_Fuzz_Test is Base_Test {
    struct Data {
        uint8 aDecimals;
    }

    function _fuzzTestSetupAfter(Data memory data) public {
        data.aDecimals = uint8(
            bound(data.aDecimals, Constants.MIN_ACCOUNTING_TOKEN_DECIMALS, Constants.MAX_ACCOUNTING_TOKEN_DECIMALS)
        );

        accountingToken = new MockERC20("Accounting Token", "ACT", data.aDecimals);

        MockPriceFeed aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine,) = _deployMachine(address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));
    }

    function test_convertToShares_fuzz(Data memory data, uint256 assets) public {
        _fuzzTestSetupAfter(data);
        assets = bound(assets, 0, 1e40);

        // deposit assets into the machine
        accountingToken.mint(address(this), assets);
        accountingToken.approve(address(machine), assets);
        machine.deposit(assets, address(this));

        // should hold when no yield occurred
        assertEq(machine.convertToShares(10 ** accountingToken.decimals()), 10 ** Constants.SHARE_TOKEN_DECIMALS);
    }

    function test_deposit_fuzz(Data memory data, uint256 assets1, uint256 assets2, uint256 yield, bool yieldDirection)
        public
    {
        _fuzzTestSetupAfter(data);
        assets1 = bound(assets1, 0, 1e30);
        assets2 = bound(assets2, 0, 1e30);

        IERC20 shareToken = IERC20(machine.shareToken());

        deal(address(accountingToken), address(this), assets1, true);

        // 1st deposit
        uint256 expectedShares1 = machine.convertToShares(assets1);
        accountingToken.approve(address(machine), assets1);
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.Deposit(address(this), address(this), assets1, expectedShares1);
        machine.deposit(assets1, address(this));

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

        deal(address(accountingToken), address(this), assets2, true);

        // 2nd deposit
        accountingToken.approve(address(machine), assets2);
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.Deposit(address(this), address(this), assets2, expectedShares2);
        machine.deposit(assets2, address(this));

        uint256 expectedTotalAssets = yieldDirection ? assets1 + assets2 + yield : assets1 + assets2 - yield;

        assertEq(accountingToken.balanceOf(address(this)), 0);
        assertEq(accountingToken.balanceOf(address(machine)), expectedTotalAssets);
        assertEq(shareToken.balanceOf(address(this)), expectedShares1 + expectedShares2);
        assertEq(shareToken.totalSupply(), expectedShares1 + expectedShares2);
        assertEq(machine.lastTotalAum(), assets1 + assets2);
    }
}
