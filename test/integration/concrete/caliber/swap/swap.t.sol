// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {MockPool} from "test/mocks/MockPool.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract Swap_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_cannotSwapWithoutMechanicWhileNotInRecoveryMode() public {
        ISwapper.SwapOrder memory order;

        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.swap(order);

        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.swap(order);
    }

    function test_cannotSwapIntoNonBaseToken() public {
        ISwapper.SwapOrder memory order;
        vm.expectRevert(ICaliber.InvalidOutputToken.selector);
        vm.prank(mechanic);
        caliber.swap(order);
    }

    function test_cannotSwapFromBTWithValueLossTooHigh() public withTokenAsBT(address(baseToken), BASE_TOKEN_POS_ID) {
        _test_cannotSwapFromBTWithValueLossTooHigh(mechanic);
    }

    function test_swap() public {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        // swap baseToken to accountingToken
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        uint256 previewOutputAmount1 = pool.previewSwap(address(baseToken), inputAmount);
        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), inputAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: inputAmount,
            minOutputAmount: previewOutputAmount1
        });
        vm.prank(mechanic);
        caliber.swap(order);

        assertGe(accountingToken.balanceOf(address(caliber)), previewOutputAmount1);
        assertEq(baseToken.balanceOf(address(caliber)), 0);

        // set baseToken as an actual base token
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        // swap accountingToken to baseToken
        uint256 previewOutputAmount2 = pool.previewSwap(address(accountingToken), previewOutputAmount1);
        order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(accountingToken), previewOutputAmount1)),
            inputToken: address(accountingToken),
            outputToken: address(baseToken),
            inputAmount: previewOutputAmount1,
            minOutputAmount: previewOutputAmount2
        });
        vm.prank(mechanic);
        caliber.swap(order);

        assertEq(accountingToken.balanceOf(address(caliber)), 0);
        assertGe(baseToken.balanceOf(address(caliber)), previewOutputAmount2);
    }

    function test_cannotSwapWithoutSCWhileInRecoveryMode() public whileInRecoveryMode {
        ISwapper.SwapOrder memory order;

        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.swap(order);

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.swap(order);
    }

    function test_cannotSwapIntoNonAccountingTokenWhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken), BASE_TOKEN_POS_ID)
        whileInRecoveryMode
    {
        ISwapper.SwapOrder memory order;
        vm.expectRevert(ICaliber.RecoveryMode.selector);
        vm.prank(securityCouncil);
        caliber.swap(order);

        // try to make a swap into baseToken
        uint256 inputAmount = 3e18;
        order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(accountingToken), inputAmount)),
            inputToken: address(accountingToken),
            outputToken: address(baseToken),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(ICaliber.RecoveryMode.selector);
        vm.prank(securityCouncil);
        caliber.swap(order);
    }

    function test_cannotSwapFromBTWithValueLossTooHighWhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken), BASE_TOKEN_POS_ID)
        whileInRecoveryMode
    {
        _test_cannotSwapFromBTWithValueLossTooHigh(securityCouncil);
    }

    function test_swapWhileInRecoveryMode() public whileInRecoveryMode {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        // swap baseToken to accountingToken
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        uint256 previewOutputAmount1 = pool.previewSwap(address(baseToken), inputAmount);
        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), inputAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: inputAmount,
            minOutputAmount: previewOutputAmount1
        });
        vm.prank(securityCouncil);
        caliber.swap(order);

        assertGe(accountingToken.balanceOf(address(caliber)), previewOutputAmount1);
        assertEq(baseToken.balanceOf(address(caliber)), 0);
    }

    ///
    /// Helper functions
    ///

    function _test_cannotSwapFromBTWithValueLossTooHigh(address sender) public {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        // decrease accountingToken value
        aPriceFeed1.setLatestAnswer(
            aPriceFeed1.latestAnswer() * int256(10_000 - DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS - 1) / 10_000
        );

        // check cannot swap baseToken to accountingToken
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        uint256 previewOutputAmount = pool.previewSwap(address(baseToken), inputAmount);
        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), inputAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: inputAmount,
            minOutputAmount: previewOutputAmount
        });

        vm.prank(sender);
        vm.expectRevert(ICaliber.MaxValueLossExceeded.selector);
        caliber.swap(order);
    }
}
