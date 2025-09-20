// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract ManagePosition_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        baseToken.scheduleReenter(
            MockERC20.Type.Before,
            address(caliber),
            abi.encodeCall(ICaliber.managePosition, (mgmtInstruction, acctInstruction))
        );

        vm.expectRevert();
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        ICaliber.Instruction memory dummyInstruction;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.managePosition(dummyInstruction, dummyInstruction);

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.managePosition(dummyInstruction, dummyInstruction);
    }

    function test_RevertWhen_PositionIdZero() public {
        uint256 inputAmount = 3e18;

        // instructions have different positionId
        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), 0, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), 0, address(vault));
        vm.expectRevert(Errors.ZeroPositionId.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedInstructionsMismatch() public {
        uint256 inputAmount = 3e18;

        vm.startPrank(mechanic);

        // instructions have different positionId
        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), POOL_POS_ID, address(vault));
        vm.expectRevert(Errors.InstructionsMismatch.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // instructions have different isDebt flags
        acctInstruction.positionId = VAULT_POS_ID;
        acctInstruction.isDebt = true;
        vm.expectRevert(Errors.InstructionsMismatch.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedFirstInstructionNonManagementType() public {
        ICaliber.Instruction memory mgmtInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        vm.expectRevert(Errors.InvalidInstructionType.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedFirstInstructionAffectedTokensListInvalid() public {
        uint256 inputAmount = 3e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockPoolAddLiquidityOneSideInstruction(POOL_POS_ID, address(pool), inputAmount, true);
        ICaliber.Instruction memory acctInstruction =
            _buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool), false);

        vm.prank(mechanic);
        vm.expectRevert(Errors.InvalidAffectedToken.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedFirstInstructionProofInvalid() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(baseToken), 0);
        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault2), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong posId
        mgmtInstruction = _build4626DepositInstruction(address(caliber), POOL_POS_ID, address(vault), inputAmount);
        acctInstruction.positionId = POOL_POS_ID;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong isDebt
        mgmtInstruction = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.isDebt = true;
        acctInstruction.isDebt = true;
        acctInstruction.positionId = VAULT_POS_ID;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong groupId
        mgmtInstruction = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.groupId = LENDING_MARKET_POS_GROUP_ID;
        acctInstruction.isDebt = false;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong affected tokens list
        mgmtInstruction = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.affectedTokens[0] = address(0);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong commands
        mgmtInstruction = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.commands[1] = mgmtInstruction.commands[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong state
        mgmtInstruction = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.state[2] = mgmtInstruction.state[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong bitmap
        mgmtInstruction = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        mgmtInstruction.stateBitmap = 0;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertGiven_WrongRoot() public withTokenAsBT(address(baseToken)) {
        vm.prank(riskManagerTimelock);
        caliber.setCooldownDuration(0);

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // schedule root update with a wrong root
        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(keccak256(abi.encodePacked("wrongRoot")));

        // instruction can still be executed while the update is pending
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        skip(caliber.timelockDuration());

        // instruction cannot be executed after the update takes effect
        vm.prank(mechanic);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // schedule root update with the correct root
        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(allowedInstrMerkleRoot);

        // instruction cannot be executed while the update is pending
        vm.prank(mechanic);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        skip(caliber.timelockDuration());

        // instruction can be executed after the update takes effect
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedSecondInstructionNonAccountingType() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.prank(mechanic);
        vm.expectRevert(Errors.InvalidInstructionType.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedSecondInstructionProofInvalid() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(baseToken), 0);
        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault2));
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong affected tokens list
        acctInstruction.affectedTokens[0] = address(0);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong commands
        delete acctInstruction.commands[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong state
        delete acctInstruction.state[2];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // use wrong bitmap
        acctInstruction.stateBitmap = 0;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertGiven_AccountingOutputStateInvalid() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockPoolAddLiquidityOneSideInstruction(POOL_POS_ID, address(pool), inputAmount, false);
        ICaliber.Instruction memory acctInstruction =
            _buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool), true);

        // replace end flag with null value in accounting output state
        delete acctInstruction.state[1];
        vm.prank(mechanic);
        vm.expectRevert(Errors.InvalidAccounting.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedSecondInstructionAffectedTokensListInvalid() public {
        uint256 inputAmount = 3e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockPoolAddLiquidityOneSideInstruction(POOL_POS_ID, address(pool), inputAmount, false);
        ICaliber.Instruction memory acctInstruction =
            _buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool), true);

        vm.prank(mechanic);
        vm.expectRevert(Errors.InvalidAffectedToken.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_OngoingCooldown() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // try to create position
        vm.prank(mechanic);
        vm.expectRevert(Errors.OngoingCooldown.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are spent but non-debt position decreases
    function test_RevertGiven_InvalidPositionChangeDirection_NonDebt() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in supplyModule
        supplyModule.setFaultyMode(true);

        // try increase position
        vm.prank(mechanic);
        vm.expectRevert(Errors.InvalidPositionChangeDirection.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are spent but debt position increases
    function test_RevertGiven_InvalidPositionChangeDirection_Debt() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in borrowModule
        borrowModule.setFaultyMode(true);

        mgmtInstruction = _buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        // try repay debt
        vm.prank(mechanic);
        vm.expectRevert(Errors.InvalidPositionChangeDirection.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // non-debt position does not increase as much as expected
    function test_RevertGiven_ValueLossTooHigh_PositionIncrease_NonDebt() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        // decrease borrowModule rate
        supplyModule.setRateBps(10_000 - DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS - 1);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // try create position
        vm.prank(mechanic);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // non-debt position increases more than expected
    function test_RevertGiven_ValueLossTooHigh_PositionIncrease_Debt() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), inputAmount, true);

        // increase borrowModule rate
        borrowModule.setRateBps(10_000 + DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS + 1);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // try create position
        vm.prank(mechanic);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // non-debt position decreases more than expected
    function test_RevertGiven_ValueLossTooHigh_PositionDecrease_NonDebt() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // increase supplyModule rate
        supplyModule.setRateBps(10_000 + DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS + 1);

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        // try decrease position
        vm.prank(mechanic);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // check that execution succeeds when value loss reaches the position increase loss threshold,
        // intended to be stricter than the position decrease loss threshold
        supplyModule.setRateBps(10_000 + DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS + 1);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // debt position does not decrease as much as expected
    function test_RevertGiven_ValueLossTooHigh_PositionDecrease_Debt() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // decrease borrowModule rate
        borrowModule.setRateBps(10_000 - DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS - 1);

        mgmtInstruction = _buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        vm.prank(mechanic);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // check that execution succeeds when value loss reaches the position increase loss threshold,
        // intended to be stricter than the position decrease loss threshold
        borrowModule.setRateBps(10_000 - DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS - 1);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are received but non-debt position increases
    function test_FavorableMove_PositionIncrease_NonDebt() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in supplyModule
        supplyModule.setFaultyMode(true);

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        // try decrease position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are received but debt position decreases
    function test_FavorableMove_PositionDecrease_Debt() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in borrowModule
        borrowModule.setFaultyMode(true);

        mgmtInstruction = _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        // try increase position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_GroupedPositionInvalidation() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 1e18;

        // create supply position
        deal(address(baseToken), address(caliber), inputAmount, true);
        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // create borrow position
        deal(address(baseToken), address(borrowModule), 2 * inputAmount, true);
        mgmtInstruction = _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPosition(SUPPLY_POS_ID).lastAccountingTime, 0);
    }

    function test_NonGroupedPositionNoInvalidation() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 1e18;

        // create vault position
        deal(address(baseToken), address(caliber), inputAmount, true);
        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // create supply position
        deal(address(baseToken), address(caliber), inputAmount, true);
        mgmtInstruction = _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPosition(VAULT_POS_ID).lastAccountingTime, block.timestamp);

        // create pool position
        deal(address(accountingToken), address(caliber), inputAmount, true);
        mgmtInstruction = _buildMockPoolAddLiquidityOneSideInstruction(POOL_POS_ID, address(pool), inputAmount, false);
        acctInstruction = _buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool), false);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPosition(VAULT_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).lastAccountingTime, block.timestamp);
    }

    function test_ManagePosition_4626_Create() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        uint256 expectedPosValue = inputAmount * PRICE_B_A;

        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.PositionCreated(VAULT_POS_ID, expectedPosValue);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), 1);
        assertEq(caliber.getPositionId(0), VAULT_POS_ID);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(value, uint256(change));
        assertEq(value, expectedPosValue);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, value);
        assertEq(caliber.getPosition(VAULT_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(VAULT_POS_ID).isDebt, false);
    }

    function test_ManagePosition_SupplyModule_Create() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        uint256 expectedPosValue = inputAmount * PRICE_B_A;

        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.PositionCreated(SUPPLY_POS_ID, expectedPosValue);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), 1);
        assertEq(caliber.getPositionId(0), SUPPLY_POS_ID);
        assertEq(supplyModule.collateralOf(address(caliber)), inputAmount);
        assertEq(value, uint256(change));
        assertEq(value, expectedPosValue);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, value);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).isDebt, false);
    }

    function test_ManagePosition_BorrowModule_Create() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        uint256 expectedPosValue = inputAmount * PRICE_B_A;

        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.PositionCreated(BORROW_POS_ID, expectedPosValue);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), 1);
        assertEq(caliber.getPositionId(0), BORROW_POS_ID);
        assertEq(borrowModule.debtOf(address(caliber)), inputAmount);
        assertEq(value, uint256(change));
        assertEq(value, expectedPosValue);
        assertEq(caliber.getPosition(BORROW_POS_ID).value, value);
        assertEq(caliber.getPosition(BORROW_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(BORROW_POS_ID).isDebt, true);
    }

    function test_ManagePosition_MockPool_Create() public withTokenAsBT(address(baseToken)) {
        // a1 >= 0.99 * (a0 + a1)
        // <=> a1 >= (0.99 / 0.01) * a0
        uint256 assets0 = 1e30 * PRICE_B_A;
        uint256 assets1 =
            (1e30 * (10_000 - DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS) / DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS);
        uint256 previewLpts = pool.previewAddLiquidity(assets0, assets1);

        deal(address(accountingToken), address(caliber), assets0, true);
        deal(address(baseToken), address(caliber), assets1, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockPoolAddLiquidityInstruction(POOL_POS_ID, address(pool), assets0, assets1);
        ICaliber.Instruction memory acctInstruction =
            _buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool), true);

        uint256 expectedPosValue = assets1 * PRICE_B_A;

        // create position
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.PositionCreated(POOL_POS_ID, expectedPosValue);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), 1);
        assertEq(caliber.getPositionId(0), POOL_POS_ID);
        assertEq(pool.balanceOf(address(caliber)), previewLpts);
        assertEq(value, uint256(change));
        assertEq(value, expectedPosValue);
        assertEq(caliber.getPosition(POOL_POS_ID).value, value);
        assertEq(caliber.getPosition(POOL_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(POOL_POS_ID).isDebt, false);
    }

    function test_ManagePosition_4626_Increase() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();
        previewShares += vault.previewDeposit(inputAmount);

        skip(DEFAULT_CALIBER_COOLDOWN_DURATION);

        uint256 expectedPosValue = 2 * inputAmount * PRICE_B_A;

        // increase position
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.PositionUpdated(VAULT_POS_ID, expectedPosValue);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), posLengthBefore);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(value, expectedPosValue);
        assertEq(uint256(change), inputAmount * PRICE_B_A);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, value);
        assertEq(caliber.getPosition(VAULT_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(VAULT_POS_ID).isDebt, false);
    }

    function test_ManagePosition_SupplyModule_Increase() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();

        skip(DEFAULT_CALIBER_COOLDOWN_DURATION);

        uint256 expectedPosValue = 2 * inputAmount * PRICE_B_A;

        // increase position
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.PositionUpdated(SUPPLY_POS_ID, expectedPosValue);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), posLengthBefore);
        assertEq(supplyModule.collateralOf(address(caliber)), 2 * inputAmount);
        assertEq(value, 2 * inputAmount * PRICE_B_A);
        assertEq(uint256(change), inputAmount * PRICE_B_A);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, value);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).isDebt, false);
    }

    function test_ManagePosition_BorrowModule_Increase() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();

        skip(DEFAULT_CALIBER_COOLDOWN_DURATION);

        uint256 expectedPosValue = 2 * inputAmount * PRICE_B_A;

        // increase position
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.PositionUpdated(BORROW_POS_ID, expectedPosValue);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), posLengthBefore);
        assertEq(borrowModule.debtOf(address(caliber)), 2 * inputAmount);
        assertEq(value, expectedPosValue);
        assertEq(uint256(change), inputAmount * PRICE_B_A);
        assertEq(caliber.getPosition(BORROW_POS_ID).value, value);
        assertEq(caliber.getPosition(BORROW_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(BORROW_POS_ID).isDebt, true);
    }

    function test_ManagePosition_4626_Decrease() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();

        uint256 sharesToRedeem = vault.balanceOf(address(caliber)) / 2;

        mgmtInstruction = _build4626RedeemInstruction(address(caliber), VAULT_POS_ID, address(vault), sharesToRedeem);

        uint256 expectedPosValue = (previewShares - sharesToRedeem) * PRICE_B_A;

        // decrease position
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.PositionUpdated(VAULT_POS_ID, expectedPosValue);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), posLengthBefore);
        assertEq(vault.balanceOf(address(caliber)), previewShares - sharesToRedeem);
        assertEq(value, expectedPosValue);
        assertEq(change, -1 * int256(sharesToRedeem * PRICE_B_A));
        assertEq(
            caliber.getPosition(VAULT_POS_ID).value, vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A
        );
        assertEq(caliber.getPosition(VAULT_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(VAULT_POS_ID).isDebt, false);
    }

    function test_ManagePosition_SupplyModule_Decrease() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();

        uint256 withdrawAmount = inputAmount / 2;

        mgmtInstruction =
            _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), withdrawAmount);

        uint256 expectedPosValue = (inputAmount - withdrawAmount) * PRICE_B_A;

        // decrease position
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.PositionUpdated(SUPPLY_POS_ID, expectedPosValue);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), posLengthBefore);
        assertEq(supplyModule.collateralOf(address(caliber)), inputAmount - withdrawAmount);
        assertEq(value, (inputAmount - withdrawAmount) * PRICE_B_A);
        assertEq(change, -1 * int256(withdrawAmount * PRICE_B_A));
        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, supplyModule.collateralOf(address(caliber)) * PRICE_B_A);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).isDebt, false);
    }

    function test_ManagePosition_BorrowModule_Decrease() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();

        uint256 repayAmount = inputAmount / 2;

        mgmtInstruction = _buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), repayAmount);

        uint256 expectedPosValue = (inputAmount - repayAmount) * PRICE_B_A;

        // decrease position
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.PositionUpdated(BORROW_POS_ID, expectedPosValue);
        vm.prank(mechanic);
        (uint256 value, int256 change) = caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), posLengthBefore);
        assertEq(borrowModule.debtOf(address(caliber)), inputAmount - repayAmount);
        assertEq(value, expectedPosValue);
        assertEq(change, -1 * int256(repayAmount * PRICE_B_A));
        assertEq(caliber.getPosition(BORROW_POS_ID).value, borrowModule.debtOf(address(caliber)) * PRICE_B_A);
        assertEq(caliber.getPosition(BORROW_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(BORROW_POS_ID).isDebt, true);
    }

    function test_ManagePosition_4626_Close() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();

        mgmtInstruction = _build4626RedeemInstruction(
            address(caliber), VAULT_POS_ID, address(vault), vault.balanceOf(address(caliber))
        );

        // close position
        vm.expectEmit(true, false, false, false, address(caliber));
        emit ICaliber.PositionClosed(VAULT_POS_ID);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), posLengthBefore - 1);
        assertEq(vault.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, 0);
        assertEq(caliber.getPosition(VAULT_POS_ID).isDebt, false);
    }

    function test_ManagePosition_SupplyModule_Close() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        // close position
        vm.expectEmit(true, false, false, false, address(caliber));
        emit ICaliber.PositionClosed(SUPPLY_POS_ID);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), posLengthBefore - 1);
        assertEq(borrowModule.debtOf(address(caliber)), 0);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, 0);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).isDebt, false);
    }

    function test_ManagePosition_BorrowModule_Close() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();

        mgmtInstruction = _buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        // close position
        vm.expectEmit(true, false, false, false, address(caliber));
        emit ICaliber.PositionClosed(BORROW_POS_ID);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), posLengthBefore - 1);
        assertEq(borrowModule.debtOf(address(caliber)), 0);
        assertEq(caliber.getPosition(BORROW_POS_ID).value, 0);
        assertEq(caliber.getPosition(BORROW_POS_ID).isDebt, false);
    }

    function test_ManagePosition_MockPool_Close() public withTokenAsBT(address(baseToken)) {
        // a1 >= 0.99 * (a0 + a1)
        // <=> a1 >= (0.99 / 0.01) * a0
        uint256 assets0 = 1e30 * PRICE_B_A;
        uint256 assets1 =
            1e30 * (10_000 - DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS) / DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS;

        deal(address(accountingToken), address(caliber), assets0, true);
        deal(address(baseToken), address(caliber), assets1, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockPoolAddLiquidityInstruction(POOL_POS_ID, address(pool), assets0, assets1);
        ICaliber.Instruction memory acctInstruction =
            _buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool), true);

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();

        mgmtInstruction = _buildMockPoolRemoveLiquidityOneSideInstruction(
            POOL_POS_ID, address(pool), pool.balanceOf(address(caliber)), true
        );

        // close position
        vm.expectEmit(true, true, false, true, address(caliber));
        emit ICaliber.PositionClosed(POOL_POS_ID);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getPositionsLength(), posLengthBefore - 1);
        assertEq(pool.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(POOL_POS_ID).value, 0);
        assertEq(caliber.getPosition(POOL_POS_ID).isDebt, false);
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        ICaliber.Instruction memory dummyInstruction;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.managePosition(dummyInstruction, dummyInstruction);

        vm.prank(mechanic);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.managePosition(dummyInstruction, dummyInstruction);
    }

    function test_RevertWhen_OngoingCooldown_WhileInRecoveryMode() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // turn on recovery mode
        _setRecoveryMode();

        mgmtInstruction = _build4626RedeemInstruction(
            address(caliber), VAULT_POS_ID, address(vault), vault.balanceOf(address(caliber)) / 2
        );

        // decrease position
        vm.prank(securityCouncil);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // try to decrease position again
        vm.prank(securityCouncil);
        vm.expectRevert(Errors.OngoingCooldown.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertGiven_PositionIncrease_NonDebt_WhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken))
        whileInRecoveryMode
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position
        vm.prank(securityCouncil);
        vm.expectRevert(Errors.RecoveryMode.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertGiven_PositionIncrease_Debt_WhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken))
        whileInRecoveryMode
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // create position
        vm.prank(securityCouncil);
        vm.expectRevert(Errors.RecoveryMode.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are spent but non-debt position decreases
    function test_RevertGiven_InvalidPositionChangeDirection_NonDebt_WhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken))
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in supplyModule
        supplyModule.setFaultyMode(true);

        // turn on recovery mode
        _setRecoveryMode();

        // try increase position
        vm.prank(securityCouncil);
        vm.expectRevert(Errors.InvalidPositionChangeDirection.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // non-debt position decreases more than expected
    function test_RevertGiven_ValueLossTooHigh_PositionDecrease_NonDebt_WhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken))
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // increase supplyModule rate
        supplyModule.setRateBps(10_000 + DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS + 1);

        // turn on recovery mode
        _setRecoveryMode();

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        // try decrease position
        vm.prank(securityCouncil);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // check that execution succeeds when value loss reaches the position increase loss threshold,
        // intended to be stricter than the position decrease loss threshold
        supplyModule.setRateBps(10_000 + DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS + 1);
        vm.prank(securityCouncil);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // debt position does not decrease as much as expected
    function test_RevertGiven_ValueLossTooHigh_PositionDecrease_Debt_WhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken))
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // decrease borrowModule rate
        borrowModule.setRateBps(10_000 - DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS - 1);

        // turn on recovery mode
        _setRecoveryMode();

        mgmtInstruction = _buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // check that execution succeeds when value loss reaches the position increase loss threshold,
        // intended to be stricter than the position decrease loss threshold
        borrowModule.setRateBps(10_000 - DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS - 1);
        vm.prank(securityCouncil);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are received but non-debt position increases
    function test_RevertGiven_FavorableMove_PositionIncrease_NonDebt_WhileInRecoveryMode()
        public
        withTokenAsBT(address(baseToken))
    {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in supplyModule
        supplyModule.setFaultyMode(true);

        // turn on recovery mode
        _setRecoveryMode();

        mgmtInstruction = _buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        // try decrease position
        vm.prank(securityCouncil);
        vm.expectRevert(Errors.RecoveryMode.selector);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    // base tokens are received but debt position decreases
    function test_FavorableMove_PositionDecrease_Debt_WhileInRecoveryMode() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // create position
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // trigger faulty mode in borrowModule
        borrowModule.setFaultyMode(true);

        // turn on recovery mode
        _setRecoveryMode();

        mgmtInstruction = _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        // try increase position
        vm.prank(securityCouncil);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_PositionDecrease_WhileInRecoveryMode() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create a new position with mechanic
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 receivedShares = vault.balanceOf(address(caliber));
        uint256 posLengthBefore = caliber.getPositionsLength();

        // turn on recovery mode
        _setRecoveryMode();

        // check security council can decrease position
        uint256 sharesToRedeem = receivedShares / 2;
        mgmtInstruction = _build4626RedeemInstruction(address(caliber), VAULT_POS_ID, address(vault), sharesToRedeem);
        vm.prank(securityCouncil);
        caliber.managePosition(mgmtInstruction, acctInstruction);
        assertEq(caliber.getPositionsLength(), posLengthBefore);
        assertEq(vault.balanceOf(address(caliber)), receivedShares - sharesToRedeem);
        assertEq(
            caliber.getPosition(VAULT_POS_ID).value, vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A
        );
    }

    function test_PositionClosed_WhileInRecoveryMode() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create a new position with mechanic
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 posLengthBefore = caliber.getPositionsLength();

        // turn on recovery mode
        _setRecoveryMode();

        // check that security council can close position
        mgmtInstruction = _build4626RedeemInstruction(
            address(caliber), VAULT_POS_ID, address(vault), vault.balanceOf(address(caliber))
        );
        vm.prank(securityCouncil);
        caliber.managePosition(mgmtInstruction, acctInstruction);
        assertEq(caliber.getPositionsLength(), posLengthBefore - 1);
        assertEq(vault.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, 0);
    }

    function _setRecoveryMode() internal {
        vm.prank(securityCouncil);
        machine.setRecoveryMode(true);
    }
}
