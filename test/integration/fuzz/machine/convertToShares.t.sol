// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {Machine} from "src/machine/Machine.sol";
import {Constants} from "src/libraries/Constants.sol";

import {Base_Hub_Test} from "test/base/Base.t.sol";

contract ConvertToShares_Integration_Fuzz_Test is Base_Hub_Test {
    MockERC20 public accountingToken;

    Machine public machine;

    function _fuzzTestSetupAfter(uint256 atDecimals) public {
        atDecimals =
            uint8(bound(atDecimals, Constants.MIN_ACCOUNTING_TOKEN_DECIMALS, Constants.MAX_ACCOUNTING_TOKEN_DECIMALS));

        accountingToken = new MockERC20("Accounting Token", "ACT", atDecimals);

        MockPriceFeed aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine,,) = _deployMachine(address(accountingToken), bytes32(0), address(0));
    }

    function testFuzz_ConvertToShares(uint256 atDecimals, uint256 assets) public {
        _fuzzTestSetupAfter(atDecimals);
        assets = bound(assets, 0, 1e40);

        // deposit assets into the machine
        deal(address(accountingToken), machineDepositor, assets, true);
        vm.startPrank(machineDepositor);
        accountingToken.approve(address(machine), assets);
        machine.deposit(assets, address(this));

        // should hold when no yield occurred
        assertEq(machine.convertToShares(10 ** accountingToken.decimals()), 10 ** Constants.SHARE_TOKEN_DECIMALS);
    }
}
