// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

import {Swapper_Unit_Concrete_Test} from "../Swapper.t.sol";

contract Swap_Unit_Concrete_Test is Swapper_Unit_Concrete_Test {
    MockERC20 internal token0;
    MockERC20 internal token1;

    // mock pool contract to simulate Dex aggregrator
    MockPool internal pool;

    uint256 internal initialPoolLiquidityOneSide;

    function setUp() public override {
        Swapper_Unit_Concrete_Test.setUp();

        token0 = new MockERC20("token0", "T1", 18);
        token1 = new MockERC20("token1", "T2", 18);

        pool = new MockPool(address(token0), address(token1), "MockPool", "MPL");
        initialPoolLiquidityOneSide = 1e30;
        deal(address(token0), address(this), initialPoolLiquidityOneSide, true);
        deal(address(token1), address(this), initialPoolLiquidityOneSide, true);
        token0.approve(address(pool), initialPoolLiquidityOneSide);
        token1.approve(address(pool), initialPoolLiquidityOneSide);
        pool.addLiquidity(initialPoolLiquidityOneSide, initialPoolLiquidityOneSide);
    }

    function test_RevertGiven_TargetsNotSet() public {
        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: bytes(""),
            inputToken: address(0),
            outputToken: address(token1),
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

    function test_RevertGiven_InsufficientAllowance() public {
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));

        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: bytes(""),
            inputToken: address(token1),
            outputToken: address(0),
            inputAmount: 1e18,
            minOutputAmount: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(swapper), 0, order.inputAmount
            )
        );
        swapper.swap(order);
    }

    function test_RevertGiven_InsufficientBalance() public {
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));

        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: bytes(""),
            inputToken: address(token1),
            outputToken: address(0),
            inputAmount: 1e18,
            minOutputAmount: 0
        });

        token1.approve(address(swapper), order.inputAmount);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 0, order.inputAmount)
        );
        swapper.swap(order);
    }

    function test_RevertGiven_DexAggregatorExecutionFails() public {
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));

        uint256 inputAmount = initialPoolLiquidityOneSide + 1;
        deal(address(token0), address(this), inputAmount, true);
        token0.approve(address(swapper), inputAmount);

        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(token0), inputAmount)),
            inputToken: address(token0),
            outputToken: address(token1),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(ISwapper.SwapFailed.selector);
        swapper.swap(order);
    }

    function test_RevertGiven_AmountOutTooLow() public {
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));

        uint256 inputAmount = 1e18;
        deal(address(token0), address(this), inputAmount, true);
        token0.approve(address(swapper), inputAmount);

        uint256 previewSwap = pool.previewSwap(address(token0), inputAmount);

        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(token0), inputAmount)),
            inputToken: address(token0),
            outputToken: address(token1),
            inputAmount: inputAmount,
            minOutputAmount: previewSwap + 1
        });

        vm.expectRevert(ISwapper.AmountOutTooLow.selector);
        swapper.swap(order);
    }

    function test_Swap() public {
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));

        uint256 inputAmount = 1e18;
        deal(address(token0), address(this), inputAmount, true);
        token0.approve(address(swapper), inputAmount);

        uint256 previewSwap = pool.previewSwap(address(token0), inputAmount);

        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(token0), inputAmount)),
            inputToken: address(token0),
            outputToken: address(token1),
            inputAmount: inputAmount,
            minOutputAmount: previewSwap
        });

        vm.expectEmit(true, true, true, true, address(swapper));
        emit ISwapper.Swapped(
            address(this), ISwapper.DexAggregator.ZEROX, address(token0), address(token1), inputAmount, previewSwap
        );
        uint256 outputAmount = swapper.swap(order);

        assertEq(outputAmount, previewSwap);
        assertEq(token1.balanceOf(address(this)), outputAmount);
    }
}
