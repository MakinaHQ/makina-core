// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {ISwapModule} from "src/interfaces/ISwapModule.sol";
import {Errors} from "src/libraries/Errors.sol";

import {Unit_Concrete_Spoke_Test} from "../../UnitConcrete.t.sol";

contract Swap_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    MockERC20 internal token0;
    MockERC20 internal token1;

    // mock pool contract to simulate Dex aggregrator
    MockPool internal pool;

    uint256 internal initialPoolLiquidityOneSide;

    function setUp() public override {
        Unit_Concrete_Spoke_Test.setUp();

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

    function test_RevertGiven_CallerNotCaliber() public {
        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: bytes(""),
            inputToken: address(0),
            outputToken: address(token1),
            inputAmount: 1e18,
            minOutputAmount: 0
        });

        vm.expectRevert(Errors.NotCaliber.selector);
        swapModule.swap(order);
    }

    function test_RevertGiven_TargetsNotSet() public {
        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: bytes(""),
            inputToken: address(0),
            outputToken: address(token1),
            inputAmount: 1e18,
            minOutputAmount: 0
        });

        vm.expectRevert(Errors.SwapperTargetsNotSet.selector);
        vm.prank(address(caliber));
        swapModule.swap(order);

        vm.prank(dao);
        swapModule.setSwapperTargets(ZEROX_SWAPPER_ID, address(1), address(0));
        vm.expectRevert(Errors.SwapperTargetsNotSet.selector);
        vm.prank(address(caliber));
        swapModule.swap(order);

        vm.prank(dao);
        swapModule.setSwapperTargets(ZEROX_SWAPPER_ID, address(0), address(1));
        vm.expectRevert(Errors.SwapperTargetsNotSet.selector);
        vm.prank(address(caliber));
        swapModule.swap(order);
    }

    function test_RevertGiven_InsufficientAllowance() public {
        vm.prank(dao);
        swapModule.setSwapperTargets(ZEROX_SWAPPER_ID, address(pool), address(pool));

        uint256 inputAmount = 1e18;

        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: bytes(""),
            inputToken: address(token1),
            outputToken: address(0),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(swapModule), 0, inputAmount
            )
        );
        vm.prank(address(caliber));
        swapModule.swap(order);
    }

    function test_RevertGiven_InsufficientBalance() public {
        vm.prank(dao);
        swapModule.setSwapperTargets(ZEROX_SWAPPER_ID, address(pool), address(pool));

        uint256 inputAmount = 1e18;

        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: bytes(""),
            inputToken: address(token1),
            outputToken: address(0),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.startPrank(address(caliber));
        token1.approve(address(swapModule), inputAmount);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(caliber), 0, inputAmount)
        );
        swapModule.swap(order);
    }

    function test_RevertGiven_SwapperExecutionFails() public {
        vm.prank(dao);
        swapModule.setSwapperTargets(ZEROX_SWAPPER_ID, address(pool), address(pool));

        uint256 inputAmount = initialPoolLiquidityOneSide + 1;
        deal(address(token0), address(caliber), inputAmount, true);

        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: abi.encodeCall(MockPool.swap, (address(token0), inputAmount)),
            inputToken: address(token0),
            outputToken: address(token1),
            inputAmount: inputAmount,
            minOutputAmount: 0
        });

        vm.startPrank(address(caliber));
        token0.approve(address(swapModule), inputAmount);

        vm.expectRevert(Errors.SwapFailed.selector);
        swapModule.swap(order);
    }

    function test_RevertGiven_AmountOutTooLow() public {
        vm.prank(dao);
        swapModule.setSwapperTargets(ZEROX_SWAPPER_ID, address(pool), address(pool));

        uint256 inputAmount = 1e18;
        deal(address(token0), address(caliber), inputAmount, true);

        uint256 previewSwap = pool.previewSwap(address(token0), inputAmount);

        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: abi.encodeCall(MockPool.swap, (address(token0), inputAmount)),
            inputToken: address(token0),
            outputToken: address(token1),
            inputAmount: inputAmount,
            minOutputAmount: previewSwap + 1
        });

        vm.startPrank(address(caliber));
        token0.approve(address(swapModule), inputAmount);

        vm.expectRevert(Errors.AmountOutTooLow.selector);
        swapModule.swap(order);
    }

    function test_Swap() public {
        vm.prank(dao);
        swapModule.setSwapperTargets(ZEROX_SWAPPER_ID, address(pool), address(pool));

        uint256 inputAmount = 1e18;
        deal(address(token0), address(caliber), inputAmount, true);

        uint256 previewSwap = pool.previewSwap(address(token0), inputAmount);

        ISwapModule.SwapOrder memory order = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: abi.encodeCall(MockPool.swap, (address(token0), inputAmount)),
            inputToken: address(token0),
            outputToken: address(token1),
            inputAmount: inputAmount,
            minOutputAmount: previewSwap
        });

        vm.startPrank(address(caliber));
        token0.approve(address(swapModule), inputAmount);

        vm.expectEmit(true, true, true, true, address(swapModule));
        emit ISwapModule.Swap(
            address(caliber), ZEROX_SWAPPER_ID, address(token0), address(token1), inputAmount, previewSwap
        );
        uint256 outputAmount = swapModule.swap(order);

        assertEq(outputAmount, previewSwap);
        assertEq(token1.balanceOf(address(caliber)), outputAmount);
    }
}
