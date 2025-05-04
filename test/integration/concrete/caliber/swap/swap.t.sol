// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {ISwapModule} from "src/interfaces/ISwapModule.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract Swap_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        _addLiquidityToMockPool(1, 1);
        uint256 inputAmount = 1;
        deal(address(baseToken), address(caliber), inputAmount, true);
        uint256 previewOutputAmount1 = pool.previewSwap(address(baseToken), inputAmount);
        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), inputAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: inputAmount,
            minOutputAmount: previewOutputAmount1
        });

        baseToken.scheduleReenter(MockERC20.Type.Before, address(caliber), abi.encodeCall(ICaliber.swap, (order)));

        vm.expectRevert();
        vm.prank(mechanic);
        caliber.swap(order);
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        ISwapModule.SwapOrder memory order;

        vm.expectRevert(IMakinaGovernable.UnauthorizedCaller.selector);
        caliber.swap(order);

        vm.prank(securityCouncil);
        vm.expectRevert(IMakinaGovernable.UnauthorizedCaller.selector);
        caliber.swap(order);
    }

    function test_RevertWhen_OutputTokenNonBaseToken() public {
        ISwapModule.SwapOrder memory order;
        vm.expectRevert(ICaliber.InvalidOutputToken.selector);
        vm.prank(mechanic);
        caliber.swap(order);
    }

    function test_RevertWhen_OngoingCooldown() public withTokenAsBT(address(baseToken)) {
        _test_RevertWhen_OngoingCooldown(mechanic);
    }

    function test_RevertGiven_SwapFromBTWithValueLossTooHigh() public withTokenAsBT(address(baseToken)) {
        _test_RevertGiven_SwapFromBTWithValueLossTooHigh(mechanic);
    }

    function test_Swap() public {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        // swap baseToken to accountingToken
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        uint256 previewOutputAmount1 = pool.previewSwap(address(baseToken), inputAmount);
        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
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
        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(baseToken));

        // swap accountingToken to baseToken
        uint256 previewOutputAmount2 = pool.previewSwap(address(accountingToken), previewOutputAmount1);
        order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
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

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        ISwapModule.SwapOrder memory order;

        vm.expectRevert(IMakinaGovernable.UnauthorizedCaller.selector);
        caliber.swap(order);

        vm.prank(mechanic);
        vm.expectRevert(IMakinaGovernable.UnauthorizedCaller.selector);
        caliber.swap(order);
    }

    function test_RevertWhen_OutputTokenNonAccountingToken_WhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken))
        whileInRecoveryMode
    {
        ISwapModule.SwapOrder memory order;
        vm.expectRevert(IMakinaGovernable.RecoveryMode.selector);
        vm.prank(securityCouncil);
        caliber.swap(order);

        // try to make a swap into baseToken
        uint256 inputAmount = 3e18;
        order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: abi.encodeCall(MockPool.swap, (address(accountingToken), inputAmount)),
            inputToken: address(accountingToken),
            outputToken: address(baseToken),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(IMakinaGovernable.RecoveryMode.selector);
        vm.prank(securityCouncil);
        caliber.swap(order);
    }

    function test_RevertWhen_OngoingCooldown_WhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken))
        whileInRecoveryMode
    {
        _test_RevertWhen_OngoingCooldown(securityCouncil);
    }

    function test_RevertGiven_SwapFromBTWithValueLossTooHigh_WhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken))
        whileInRecoveryMode
    {
        _test_RevertGiven_SwapFromBTWithValueLossTooHigh(securityCouncil);
    }

    function test_Swap_WhileInRecoveryMode() public whileInRecoveryMode {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        // swap baseToken to accountingToken
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        uint256 previewOutputAmount1 = pool.previewSwap(address(baseToken), inputAmount);
        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
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

    function _test_RevertWhen_OngoingCooldown(address operator) internal {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        // swap baseToken to accountingToken
        uint256 previewOutputAmount1 = pool.previewSwap(address(baseToken), inputAmount);
        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), inputAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: inputAmount,
            minOutputAmount: previewOutputAmount1
        });
        vm.prank(operator);
        caliber.swap(order);

        vm.expectRevert(ICaliber.OngoingCooldown.selector);
        vm.prank(operator);
        caliber.swap(order);
    }

    function _test_RevertGiven_SwapFromBTWithValueLossTooHigh(address operator) public {
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
        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), inputAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: inputAmount,
            minOutputAmount: previewOutputAmount
        });

        vm.prank(operator);
        vm.expectRevert(ICaliber.MaxValueLossExceeded.selector);
        caliber.swap(order);
    }
}
