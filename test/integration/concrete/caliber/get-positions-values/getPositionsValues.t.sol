// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract GetPositionsValues_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertGiven_PositionStale()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        // create a vault position
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vaultInstructions[1] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);

        skip(DEFAULT_CALIBER_POS_STALE_THRESHOLD + 1);

        vm.expectRevert(abi.encodeWithSelector(ICaliber.PositionAccountingStale.selector, VAULT_POS_ID));
        caliber.getPositionsValues();
    }

    function test_GetPositionsValues_WithZeroAum() public view {
        (uint256 netAum, bytes[] memory positionsValues) = caliber.getPositionsValues();
        assertEq(netAum, 0);
        assertEq(positionsValues.length, 1);
        _checkEncodedCaliberPosValue(positionsValues[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, 0, false);
    }

    function test_GetPositionsValues_UnregisteredToken() public {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount);

        (uint256 netAum, bytes[] memory positionsValues) = caliber.getPositionsValues();
        assertEq(netAum, 0);
        assertEq(positionsValues.length, 1);
        _checkEncodedCaliberPosValue(positionsValues[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, 0, false);
    }

    function test_GetPositionsValues_AccountingToken() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount);

        (uint256 netAum, bytes[] memory positionsValues) = caliber.getPositionsValues();
        assertEq(netAum, inputAmount);
        assertEq(positionsValues.length, 1);
        _checkEncodedCaliberPosValue(positionsValues[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, inputAmount, false);
    }

    function test_GetPositionsValues_BaseToken()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount);

        (uint256 netAum, bytes[] memory positionsValues) = caliber.getPositionsValues();
        assertEq(netAum, inputAmount * PRICE_B_A);
        assertEq(positionsValues.length, 2);
        _checkEncodedCaliberPosValue(positionsValues[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, 0, false);
        _checkEncodedCaliberPosValue(
            positionsValues[1], HUB_CALIBER_BASE_TOKEN_1_POS_ID, inputAmount * PRICE_B_A, false
        );
    }

    function test_GetPositionsValues_NonDebtPosition()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        instructions[1] = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, address(supplyModule)
        );

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        (uint256 netAum, bytes[] memory positionsValues) = caliber.getPositionsValues();
        assertEq(netAum, inputAmount * PRICE_B_A);
        assertEq(positionsValues.length, 3);
        _checkEncodedCaliberPosValue(positionsValues[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, 0, false);
        _checkEncodedCaliberPosValue(positionsValues[1], HUB_CALIBER_BASE_TOKEN_1_POS_ID, 0, false);
        _checkEncodedCaliberPosValue(positionsValues[2], SUPPLY_POS_ID, inputAmount * PRICE_B_A, false);
    }

    function test_GetPositionsValues_DebtPosition()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        instructions[1] = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        (uint256 netAum, bytes[] memory positionsValues) = caliber.getPositionsValues();
        assertEq(netAum, 0);
        assertEq(positionsValues.length, 3);
        _checkEncodedCaliberPosValue(positionsValues[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, 0, false);
        _checkEncodedCaliberPosValue(
            positionsValues[1], HUB_CALIBER_BASE_TOKEN_1_POS_ID, inputAmount * PRICE_B_A, false
        );
        _checkEncodedCaliberPosValue(positionsValues[2], BORROW_POS_ID, inputAmount * PRICE_B_A, true);

        // increase borrowModule rate
        borrowModule.setRateBps(10_000 * 2);

        caliber.accountForPosition(instructions[1]);

        (netAum, positionsValues) = caliber.getPositionsValues();
        assertEq(netAum, 0);
        assertEq(positionsValues.length, 3);
        _checkEncodedCaliberPosValue(positionsValues[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, 0, false);
        _checkEncodedCaliberPosValue(
            positionsValues[1], HUB_CALIBER_BASE_TOKEN_1_POS_ID, inputAmount * PRICE_B_A, false
        );
        _checkEncodedCaliberPosValue(positionsValues[2], BORROW_POS_ID, 2 * inputAmount * PRICE_B_A, true);
    }

    function test_GetPositionsValues_MultiplePositions()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 aInputAmount = 5e20;
        uint256 bInputAmount = 1e18;

        uint256 expectedNetAUM;

        // increase accounting token position
        deal(address(accountingToken), address(caliber), aInputAmount, true);
        expectedNetAUM += aInputAmount;

        deal(address(baseToken), address(borrowModule), bInputAmount, true);

        // create debt position (should not modify net aum)
        ICaliber.Instruction[] memory borrowModuleInstructions = new ICaliber.Instruction[](2);
        borrowModuleInstructions[0] =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), bInputAmount);
        borrowModuleInstructions[1] = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, address(borrowModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(borrowModuleInstructions);

        // create supply position (should not modify net aum)
        ICaliber.Instruction[] memory supplyModuleInstructions = new ICaliber.Instruction[](2);
        supplyModuleInstructions[0] =
            WeirollUtils._buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), bInputAmount);
        supplyModuleInstructions[1] = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, address(supplyModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(supplyModuleInstructions);

        // check that AUM reflects all positions
        (uint256 netAum, bytes[] memory positionsValues) = caliber.getPositionsValues();
        assertEq(positionsValues.length, 4);
        assertEq(netAum, expectedNetAUM);
        _checkEncodedCaliberPosValue(positionsValues[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, aInputAmount, false);
        _checkEncodedCaliberPosValue(positionsValues[1], HUB_CALIBER_BASE_TOKEN_1_POS_ID, 0, false);
        _checkEncodedCaliberPosValue(positionsValues[2], BORROW_POS_ID, bInputAmount * PRICE_B_A, true);
        _checkEncodedCaliberPosValue(positionsValues[3], SUPPLY_POS_ID, bInputAmount * PRICE_B_A, false);

        // double borrowModule rate
        borrowModule.setRateBps(2 * 10_000);

        (, int256 change) = caliber.accountForPosition(borrowModuleInstructions[1]);
        expectedNetAUM -= uint256(change);

        (netAum, positionsValues) = caliber.getPositionsValues();
        assertEq(positionsValues.length, 4);
        assertEq(netAum, expectedNetAUM);
        _checkEncodedCaliberPosValue(positionsValues[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, aInputAmount, false);
        _checkEncodedCaliberPosValue(positionsValues[1], HUB_CALIBER_BASE_TOKEN_1_POS_ID, 0, false);
        _checkEncodedCaliberPosValue(positionsValues[2], BORROW_POS_ID, 2 * bInputAmount * PRICE_B_A, true);
        _checkEncodedCaliberPosValue(positionsValues[3], SUPPLY_POS_ID, bInputAmount * PRICE_B_A, false);

        // increase borrowModule rate
        borrowModule.setRateBps(1e2 * 10_000);

        caliber.accountForPosition(borrowModuleInstructions[1]);
        expectedNetAUM = 0;

        (netAum, positionsValues) = caliber.getPositionsValues();
        assertEq(positionsValues.length, 4);
        assertEq(netAum, expectedNetAUM);
        _checkEncodedCaliberPosValue(positionsValues[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, aInputAmount, false);
        _checkEncodedCaliberPosValue(positionsValues[1], HUB_CALIBER_BASE_TOKEN_1_POS_ID, 0, false);
        _checkEncodedCaliberPosValue(positionsValues[2], BORROW_POS_ID, 1e2 * bInputAmount * PRICE_B_A, true);
        _checkEncodedCaliberPosValue(positionsValues[3], SUPPLY_POS_ID, bInputAmount * PRICE_B_A, false);
    }
}
