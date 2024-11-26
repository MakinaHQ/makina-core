// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./BaseTest.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ISwapper} from "../src/interfaces/ISwapper.sol";
import {HubCaliberInbox, ICaliberInbox} from "../src/caliber/HubCaliberInbox.sol";
import {MockPool} from "./mocks/MockPool.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract SwapperTest is BaseTest {
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

    MockERC20 private baseToken;

    // mock pool contract to simulate Dex aggregrator
    MockPool private pool;

    uint256 private initialPoolLiquidityOneSide;

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

    function test_cannotSetDexAggregatorTargetsWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(0), address(0));
    }

    function test_setDexAggregatorTargets() public {
        vm.expectEmit(true, true, true, true, address(swapper));
        emit DexAggregatorTargetsSet(ISwapper.DexAggregator.ZEROX, address(1), address(2));
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(1), address(2));
        (address approvalTarget, address executionTarget) = swapper.dexAggregatorTargets(ISwapper.DexAggregator.ZEROX);
        assertEq(approvalTarget, address(1));
        assertEq(executionTarget, address(2));
    }

    function test_cannotSwapWithAggregatorNotSet() public {
        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: bytes(""),
            inputToken: address(0),
            outputToken: address(baseToken),
            inputAmount: 1e18,
            minOutputAmount: 0
        });

        vm.expectRevert(ISwapper.DexAggregatorNotSet.selector);
        swapper.swap(order);

        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(1), address(0));
        vm.expectRevert(ISwapper.DexAggregatorNotSet.selector);
        swapper.swap(order);

        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(0), address(1));
        vm.expectRevert(ISwapper.DexAggregatorNotSet.selector);
        swapper.swap(order);
    }

    function test_cannotSwapWithInsufficientBalance() public {
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));

        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: bytes(""),
            inputToken: address(baseToken),
            outputToken: address(0),
            inputAmount: 1e18,
            minOutputAmount: 0
        });

        vm.expectRevert(ISwapper.InsufficientBalance.selector);
        swapper.swap(order);
    }

    function test_swap() public {
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));

        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(swapper), inputAmount, true);

        uint256 previewSwap = pool.previewSwap(address(accountingToken), inputAmount);

        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(accountingToken), inputAmount)),
            inputToken: address(accountingToken),
            outputToken: address(baseToken),
            inputAmount: inputAmount,
            minOutputAmount: previewSwap
        });

        vm.expectEmit(true, true, true, true, address(swapper));
        emit Swapped(
            address(this),
            ISwapper.DexAggregator.ZEROX,
            address(accountingToken),
            address(baseToken),
            inputAmount,
            previewSwap
        );
        uint256 outputAmount = swapper.swap(order);

        assertEq(outputAmount, previewSwap);
        assertEq(baseToken.balanceOf(address(this)), outputAmount);
    }

    function test_cannotSwapIfAmountOutTooLow() public {
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));

        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(swapper), inputAmount, true);

        uint256 previewSwap = pool.previewSwap(address(accountingToken), inputAmount);

        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(accountingToken), inputAmount)),
            inputToken: address(accountingToken),
            outputToken: address(baseToken),
            inputAmount: inputAmount,
            minOutputAmount: previewSwap + 1
        });

        vm.expectRevert(ISwapper.AmountOutTooLow.selector);
        swapper.swap(order);
    }

    function test_swapRevertsIfDexAggregatorFails() public {
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));

        uint256 inputAmount = initialPoolLiquidityOneSide + 1;
        deal(address(accountingToken), address(swapper), inputAmount, true);

        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(accountingToken), inputAmount)),
            inputToken: address(accountingToken),
            outputToken: address(baseToken),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(ISwapper.SwapFailed.selector);
        swapper.swap(order);
    }
}
