// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ISwapModule} from "src/interfaces/ISwapModule.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPool} from "test/mocks/MockPool.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract Harvest_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        uint256 harvestAmount = 1e18;
        ICaliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapModule.SwapOrder[] memory swapOrders;

        baseToken.scheduleReenter(
            MockERC20.Type.Before, address(caliber), abi.encodeCall(ICaliber.harvest, (instruction, swapOrders))
        );

        vm.expectRevert();
        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        ICaliber.Instruction memory instruction;
        ISwapModule.SwapOrder[] memory swapOrders;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.harvest(instruction, swapOrders);

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.harvest(instruction, swapOrders);
    }

    function test_RevertWhen_InstructionNonHarvestingType() public {
        _test_RevertWhen_InstructionNonHarvestingType(mechanic);
    }

    function test_RevertWhen_ProofInvalid() public {
        _test_RevertWhen_ProofInvalid(mechanic);
    }

    function test_RevertGiven_WrongRoot() public {
        _test_RevertGiven_WrongRoot(mechanic);
    }

    function test_Harvest_NoSwap() public {
        _test_Harvest_NoSwap(mechanic);
    }

    function test_RevertWhen_OutputTokenNonBaseToken() public {
        uint256 harvestAmount = 3e18;
        ICaliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapModule.SwapOrder[] memory swapOrders = new ISwapModule.SwapOrder[](1);

        vm.expectRevert(Errors.InvalidOutputToken.selector);
        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);
    }

    function test_RevertGiven_SwapFromBTWithValueLossTooHigh() public {
        _test_RevertGiven_SwapFromBTWithValueLossTooHigh(mechanic);
    }

    function test_Harvest_WithSwap() public {
        _test_Harvest_WithSwap(mechanic);
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        ICaliber.Instruction memory instruction;
        ISwapModule.SwapOrder[] memory swapOrders;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.harvest(instruction, swapOrders);

        vm.prank(mechanic);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.harvest(instruction, swapOrders);
    }

    function test_RevertWhen_InstructionNonHarvesting_WhileInRecoveryMode() public whileInRecoveryMode {
        _test_RevertWhen_InstructionNonHarvestingType(securityCouncil);
    }

    function test_RevertWhen_ProofInvalid_WhileInRecoveryMode() public whileInRecoveryMode {
        _test_RevertWhen_ProofInvalid(securityCouncil);
    }

    function test_RevertGiven_WrongRoot_WhileInRecoveryMode() public whileInRecoveryMode {
        _test_RevertGiven_WrongRoot(securityCouncil);
    }

    function test_Harvest_NoSwap_WhileInRecoveryMode() public whileInRecoveryMode {
        _test_Harvest_NoSwap(securityCouncil);
    }

    function test_RevertWhen_OutputTokenNonAccountingToken_WhileInRecoveryMode() public whileInRecoveryMode {
        uint256 harvestAmount = 3e18;
        ICaliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapModule.SwapOrder[] memory swapOrders = new ISwapModule.SwapOrder[](1);

        vm.expectRevert(Errors.RecoveryMode.selector);
        vm.prank(securityCouncil);
        caliber.harvest(instruction, swapOrders);

        // try to make a swap into baseToken
        swapOrders[0] = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: abi.encodeCall(MockPool.swap, (address(accountingToken), harvestAmount)),
            inputToken: address(accountingToken),
            outputToken: address(baseToken),
            inputAmount: harvestAmount,
            minOutputAmount: 0
        });

        vm.expectRevert(Errors.RecoveryMode.selector);
        vm.prank(securityCouncil);
        caliber.harvest(instruction, swapOrders);
    }

    function test_RevertGiven_SwapFromBTWithValueLossTooHigh_WhileInRecoveryMode() public whileInRecoveryMode {
        _test_RevertGiven_SwapFromBTWithValueLossTooHigh(securityCouncil);
    }

    function test_HarvestWithSwap_WhileInRecoveryMode() public whileInRecoveryMode {
        _test_Harvest_WithSwap(securityCouncil);
    }

    ///
    /// Helper functions
    ///

    function _test_RevertWhen_InstructionNonHarvestingType(address sender) internal {
        ICaliber.Instruction memory instruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        ISwapModule.SwapOrder[] memory swapOrders = new ISwapModule.SwapOrder[](0);
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidInstructionType.selector);
        caliber.harvest(instruction, swapOrders);
    }

    function _test_RevertWhen_ProofInvalid(address sender) internal {
        vm.startPrank(sender);

        uint256 harvestAmount = 1e18;
        ICaliber.Instruction memory instruction;
        ISwapModule.SwapOrder[] memory swapOrders;

        // use wrong reward contract
        instruction = _buildMockRewardTokenHarvestInstruction(address(caliber), address(accountingToken), harvestAmount);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.harvest(instruction, swapOrders);

        // use wrong commands
        instruction = _buildMockRewardTokenHarvestInstruction(address(caliber), address(accountingToken), harvestAmount);
        delete instruction.commands[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.harvest(instruction, swapOrders);

        // use wrong state
        instruction = _buildMockRewardTokenHarvestInstruction(address(caliber), address(accountingToken), harvestAmount);
        delete instruction.state[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.harvest(instruction, swapOrders);

        // use wrong bitmap
        instruction = _buildMockRewardTokenHarvestInstruction(address(caliber), address(accountingToken), harvestAmount);
        instruction.stateBitmap = 0;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.harvest(instruction, swapOrders);

        vm.stopPrank();
    }

    function _test_RevertGiven_WrongRoot(address sender) internal {
        uint256 harvestAmount = 1e18;
        ICaliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapModule.SwapOrder[] memory swapOrders = new ISwapModule.SwapOrder[](0);

        vm.prank(sender);
        caliber.harvest(instruction, swapOrders);

        // schedule root update with a wrong root
        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(keccak256(abi.encodePacked("wrongRoot")));

        // instruction can still be executed while the update is pending
        vm.prank(sender);
        caliber.harvest(instruction, swapOrders);

        skip(caliber.timelockDuration());

        // instruction cannot be executed after the update takes effect
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.harvest(instruction, swapOrders);

        // schedule root update with the correct root
        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(allowedInstrMerkleRoot);

        // instruction cannot be executed while the update is pending
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.harvest(instruction, swapOrders);

        skip(caliber.timelockDuration());

        // instruction can be executed after the update takes effect
        vm.prank(sender);
        caliber.harvest(instruction, swapOrders);

        vm.stopPrank();
    }

    function _test_Harvest_NoSwap(address sender) internal {
        uint256 harvestAmount = 1e18;
        ICaliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapModule.SwapOrder[] memory swapOrders = new ISwapModule.SwapOrder[](0);

        vm.prank(sender);
        caliber.harvest(instruction, swapOrders);
        assertEq(baseToken.balanceOf(address(caliber)), harvestAmount);
    }

    function _test_RevertGiven_SwapFromBTWithValueLossTooHigh(address sender)
        internal
        withTokenAsBT(address(baseToken))
    {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        // decrease accountingToken value
        aPriceFeed1.setLatestAnswer(
            aPriceFeed1.latestAnswer() * int256(10_000 - DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS - 1) / 10_000
        );

        // check cannot harvest and swap baseToken to accountingToken
        uint256 harvestAmount = 3e18;
        ICaliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapModule.SwapOrder[] memory swapOrders = new ISwapModule.SwapOrder[](1);
        uint256 previewOutputAmount = pool.previewSwap(address(baseToken), harvestAmount);
        swapOrders[0] = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), harvestAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: harvestAmount,
            minOutputAmount: previewOutputAmount
        });
        vm.prank(sender);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        caliber.harvest(instruction, swapOrders);
    }

    function _test_Harvest_WithSwap(address sender) internal {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        uint256 harvestAmount = 1e18;
        uint256 previewOutputAmount = pool.previewSwap(address(baseToken), harvestAmount);

        ICaliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapModule.SwapOrder[] memory swapOrders = new ISwapModule.SwapOrder[](1);
        swapOrders[0] = ISwapModule.SwapOrder({
            swapperId: ZEROX_SWAPPER_ID,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), harvestAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: harvestAmount,
            minOutputAmount: previewOutputAmount
        });

        vm.prank(sender);
        caliber.harvest(instruction, swapOrders);
        assertEq(accountingToken.balanceOf(address(caliber)), previewOutputAmount);
    }
}
