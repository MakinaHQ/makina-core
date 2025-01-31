// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {MockPool} from "test/mocks/MockPool.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

import {Swapper_Unit_Concrete_Test} from "./Swapper.t.sol";

contract Swap_Unit_Concrete_Test is Swapper_Unit_Concrete_Test {
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

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(swapper), 0, order.inputAmount
            )
        );
        swapper.swap(order);
    }

    function test_swap() public {
        vm.prank(dao);
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));

        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(this), inputAmount, true);
        accountingToken.approve(address(swapper), inputAmount);

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
        deal(address(accountingToken), address(this), inputAmount, true);
        accountingToken.approve(address(swapper), inputAmount);

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
        deal(address(accountingToken), address(this), inputAmount, true);
        accountingToken.approve(address(swapper), inputAmount);

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
