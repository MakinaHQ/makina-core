// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ISwapper} from "src/interfaces/ISwapper.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPool} from "test/mocks/MockPool.sol";

import {Base_Test} from "test/BaseTest.sol";

contract Swapper_Unit_Concrete_Test is Base_Test {
    event DexAggregatorTargetsSet(
        ISwapper.DexAggregator indexed aggregator, address approvalTarget, address executionTarget
    );
    event Swapped(
        address indexed sender,
        ISwapper.DexAggregator aggregator,
        address indexed inputToken,
        address indexed outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    );

    MockERC20 internal baseToken;

    // mock pool contract to simulate Dex aggregrator
    MockPool internal pool;

    uint256 internal initialPoolLiquidityOneSide;

    function _setUp() public override {
        baseToken = new MockERC20("baseToken", "BT", 18);

        pool = new MockPool(address(accountingToken), address(baseToken), "MockPool", "MPL");
        initialPoolLiquidityOneSide = 1e30;
        deal(address(accountingToken), address(this), initialPoolLiquidityOneSide, true);
        deal(address(baseToken), address(this), initialPoolLiquidityOneSide, true);
        accountingToken.approve(address(pool), initialPoolLiquidityOneSide);
        baseToken.approve(address(pool), initialPoolLiquidityOneSide);
        pool.addLiquidity(initialPoolLiquidityOneSide, initialPoolLiquidityOneSide);
    }
}
