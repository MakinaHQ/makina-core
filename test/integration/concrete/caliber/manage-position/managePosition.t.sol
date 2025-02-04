// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract ManagePosition_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_cannotManagePositionWithoutMechanicWhileNotInRecoveryMode() public {
        ICaliber.Instruction[] memory dummyInstructions;

        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.managePosition(dummyInstructions);

        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.managePosition(dummyInstructions);
    }

    function test_cannotManagePositionWithoutExactlyTwoInstructions() public {
        uint256 inputAmount = 3e18;

        vm.startPrank(mechanic);

        // no instructions
        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](0);
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        caliber.managePosition(instructions);

        // missing second instruction
        instructions = new ICaliber.Instruction[](1);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        caliber.managePosition(instructions);

        // more than 2 instructions
        instructions = new ICaliber.Instruction[](3);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[2] = instructions[1];
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithUnmatchingInstructions() public {
        uint256 inputAmount = 3e18;

        vm.startPrank(mechanic);

        // instructions have different positionId
        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), POOL_POS_ID, address(vault));
        vm.expectRevert(ICaliber.UnmatchingInstructions.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithoutFirstInstructionOfTypeManagement() public {
        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithBaseTokenPosition()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;

        // position is a base token position
        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = WeirollUtils._build4626DepositInstruction(
            address(caliber), HUB_CALIBER_BASE_TOKEN_1_POS_ID, address(vault), inputAmount
        );
        instructions[1] = WeirollUtils._build4626AccountingInstruction(
            address(caliber), HUB_CALIBER_BASE_TOKEN_1_POS_ID, address(vault)
        );

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithInvalidAffectedTokensListInFirstInstruction() public {
        uint256 inputAmount = 3e18;

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        // baseToken is not set as an actual base token in the caliber
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAffectedToken.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithInvalidProofForFirstInstruction()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);

        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(baseToken), 0);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault2), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong posId
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), POOL_POS_ID, address(vault), inputAmount);
        instructions[1].positionId = POOL_POS_ID;
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong affected tokens list
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[0].affectedTokens[0] = address(0);
        instructions[1].positionId = VAULT_POS_ID;
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong commands
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[0].commands[1] = instructions[0].commands[0];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong state
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[0].state[2] = instructions[0].state[0];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong bitmap
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[0].stateBitmap = 0;
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithWrongRoot()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // schedule root update with a wrong root
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(keccak256(abi.encodePacked("wrongRoot")));

        // instruction can still be executed while the update is pending
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        skip(caliber.timelockDuration());

        // instruction cannot be executed after the update takes effect
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.managePosition(instructions);

        // schedule root update with the correct root
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(MerkleProofs._getAllowedInstrMerkleRoot());

        // instruction cannot be executed while the update is pending
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.managePosition(instructions);

        skip(caliber.timelockDuration());

        // instruction can be executed after the update takes effect
        vm.prank(mechanic);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithoutSecondInstructionOfTypeAccounting()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithInvalidProofForSecondInstruction()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);

        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(baseToken), 0);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault2));
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong affected tokens list
        instructions[1].affectedTokens[0] = address(0);
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong commands
        delete instructions[1].commands[0];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong state
        delete instructions[1].state[2];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong bitmap
        instructions[1].stateBitmap = 0;
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithInvalidAccountingOutputState()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._buildMockPoolAddLiquidityOneSide0Instruction(POOL_POS_ID, address(pool), inputAmount);
        instructions[1] = WeirollUtils._buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool));

        // replace end flag with null value in accounting output state
        delete instructions[1].state[1];
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithInvalidAffectedTokensListForSecondInstruction() public {
        uint256 inputAmount = 3e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._buildMockPoolAddLiquidityOneSide0Instruction(POOL_POS_ID, address(pool), inputAmount);
        instructions[1] = WeirollUtils._buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool));

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAffectedToken.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithValueLossTooHigh()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        // a1 < 0.99 * (a0 + a1)
        // <=> a1 < (0.99 / 0.01) * a0
        uint256 assets0 = 1e30 * PRICE_B_A;
        uint256 assets1 = (1e30 * (10_000 - DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS) / DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS) - 1;
        deal(address(accountingToken), address(caliber), assets0, true);
        deal(address(baseToken), address(caliber), assets1, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._buildMockPoolAddLiquidityInstruction(POOL_POS_ID, address(pool), assets0, assets1);
        instructions[1] = WeirollUtils._buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool));

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.MaxValueLossExceeded.selector);
        caliber.managePosition(instructions);
    }

    function test_managePosition_4626_create()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), 3e18, true);

        uint256 posLengthBefore = caliber.getPositionsLength();

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.PositionCreated(VAULT_POS_ID);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), posLengthBefore + 1);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(value, uint256(change));
        assertEq(value, inputAmount * PRICE_B_A);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, value);
        assertEq(caliber.getPosition(VAULT_POS_ID).lastAccountingTime, block.timestamp);
    }

    function test_managePosition_mockPool_create()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 assets0 = 1e30 * PRICE_B_A;
        uint256 assets1 = 1e30 * (10_000 - DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS) / DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS;
        uint256 previewLpts = pool.previewAddLiquidity(assets0, assets1);

        deal(address(accountingToken), address(caliber), assets0, true);
        deal(address(baseToken), address(caliber), assets1, true);

        uint256 posLengthBefore = caliber.getPositionsLength();

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._buildMockPoolAddLiquidityInstruction(POOL_POS_ID, address(pool), assets0, assets1);
        instructions[1] = WeirollUtils._buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool));

        // create position
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.PositionCreated(POOL_POS_ID);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), posLengthBefore + 1);
        assertEq(pool.balanceOf(address(caliber)), previewLpts);
        assertEq(value, uint256(change));
        assertEq(value, assets1 * PRICE_B_A);
        assertEq(caliber.getPosition(POOL_POS_ID).value, value);
        assertEq(caliber.getPosition(POOL_POS_ID).lastAccountingTime, block.timestamp);
    }

    function test_managePosition_4626_increase()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        assertEq(caliber.getPositionsLength(), 2);

        // create position
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        uint256 posLengthBefore = caliber.getPositionsLength();
        previewShares += vault.previewDeposit(inputAmount);

        // increase position
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), posLengthBefore);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(value, 2 * inputAmount * PRICE_B_A);
        assertEq(uint256(change), inputAmount * PRICE_B_A);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, value);
        assertEq(caliber.getPosition(VAULT_POS_ID).lastAccountingTime, block.timestamp);
    }

    function test_managePosition_4626_decrease()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create position
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        uint256 posLengthBefore = caliber.getPositionsLength();

        uint256 sharesToRedeem = vault.balanceOf(address(caliber)) / 2;

        instructions[0] =
            WeirollUtils._build4626RedeemInstruction(address(caliber), VAULT_POS_ID, address(vault), sharesToRedeem);

        // decrease position
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), posLengthBefore);
        assertEq(vault.balanceOf(address(caliber)), previewShares - sharesToRedeem);
        assertEq(
            caliber.getPosition(VAULT_POS_ID).value, vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A
        );
    }

    function test_managePosition_4626_close()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create position
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        uint256 posLengthBefore = caliber.getPositionsLength();

        instructions[0] = WeirollUtils._build4626RedeemInstruction(
            address(caliber), VAULT_POS_ID, address(vault), vault.balanceOf(address(caliber))
        );

        // close position
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.PositionClosed(VAULT_POS_ID);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), posLengthBefore - 1);
        assertEq(vault.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, 0);
    }

    function test_managePosition_mockPool_close()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 assets0 = 1e30 * PRICE_B_A;
        uint256 assets1 = 1e30 * (10_000 - DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS) / DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS;

        deal(address(accountingToken), address(caliber), assets0, true);
        deal(address(baseToken), address(caliber), assets1, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._buildMockPoolAddLiquidityInstruction(POOL_POS_ID, address(pool), assets0, assets1);
        instructions[1] = WeirollUtils._buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool));

        // create position
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        uint256 posLengthBefore = caliber.getPositionsLength();

        instructions[0] = WeirollUtils._buildMockPoolRemoveLiquidityOneSide1Instruction(
            POOL_POS_ID, address(pool), pool.balanceOf(address(caliber))
        );

        // close position
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.PositionClosed(POOL_POS_ID);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), posLengthBefore - 1);
        assertEq(pool.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(POOL_POS_ID).value, 0);
    }

    function test_cannotManagePositionWithoutSecurityCouncilWhileInRecoveryMode() public whileInRecoveryMode {
        ICaliber.Instruction[] memory dummyInstructions;

        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.managePosition(dummyInstructions);

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.managePosition(dummyInstructions);
    }

    function test_cannotCreatePositionWhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
        whileInRecoveryMode
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.RecoveryMode.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotIncreasePositionWhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create a new position with mechanic
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // turn on recovery mode
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        // check security council cannot increase position
        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.RecoveryMode.selector);
        caliber.managePosition(instructions);
    }

    function test_decreasePositionWhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create a new position with mechanic
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        uint256 receivedShares = vault.balanceOf(address(caliber));
        uint256 posLengthBefore = caliber.getPositionsLength();

        // turn on recovery mode
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        // check security council can decrease position
        uint256 sharesToRedeem = receivedShares / 2;
        instructions[0] =
            WeirollUtils._build4626RedeemInstruction(address(caliber), VAULT_POS_ID, address(vault), sharesToRedeem);
        vm.prank(securityCouncil);
        caliber.managePosition(instructions);
        assertEq(caliber.getPositionsLength(), posLengthBefore);
        assertEq(vault.balanceOf(address(caliber)), receivedShares - sharesToRedeem);
        assertEq(
            caliber.getPosition(VAULT_POS_ID).value, vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A
        );
    }

    function test_closePositionWhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create a new position with mechanic
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        uint256 posLengthBefore = caliber.getPositionsLength();

        // turn on recovery mode
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        // check that security council can close position
        instructions[0] = WeirollUtils._build4626RedeemInstruction(
            address(caliber), VAULT_POS_ID, address(vault), vault.balanceOf(address(caliber))
        );
        vm.prank(securityCouncil);
        caliber.managePosition(instructions);
        assertEq(caliber.getPositionsLength(), posLengthBefore - 1);
        assertEq(vault.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, 0);
    }
}
