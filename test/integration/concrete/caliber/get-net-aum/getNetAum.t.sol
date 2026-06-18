// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract GetNetAum_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertGiven_PositionStale() public withTokenAsBT(address(baseToken)) {
        // create a vault position
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        ICaliber.Instruction memory mgmtInstruction =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        skip(DEFAULT_CALIBER_POS_STALE_THRESHOLD - 1);

        caliber.getNetAum();

        skip(1);

        vm.expectRevert(abi.encodeWithSelector(Errors.PositionAccountingStale.selector, VAULT_POS_ID));
        caliber.getNetAum();
    }

    function test_RevertWhen_ReentrantCall() public withTokenAsBT(address(baseToken)) {
        uint256 supplyInputAmount = 1e18;
        deal(address(baseToken), address(caliber), supplyInputAmount, true);
        ICaliber.Instruction memory supplyMgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), supplyInputAmount);
        ICaliber.Instruction memory supplyAcctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        baseToken.scheduleReenter(MockERC20.Type.Before, address(caliber), abi.encodeCall(ICaliber.getNetAum, ()));

        vm.expectRevert();
        vm.prank(mechanic);
        caliber.managePosition(supplyMgmtInstruction, supplyAcctInstruction);
    }

    function test_GetNetAum_WithZeroAum() public view {
        assertEq(caliber.getNetAum(), 0);
    }

    function test_GetNetAum_UnregisteredToken() public {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        assertEq(caliber.getNetAum(), 0);
    }

    function test_GetNetAum_AccountingToken() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        assertEq(caliber.getNetAum(), inputAmount);
    }

    function test_GetNetAum_BaseToken() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        assertEq(caliber.getNetAum(), inputAmount * PRICE_B_A);
    }

    function test_GetNetAum_NonDebtPosition() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getNetAum(), inputAmount * PRICE_B_A);
    }

    function test_GetNetAum_DebtPosition() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(caliber.getNetAum(), 0);

        // increase borrowModule rate
        borrowModule.setRateBps(10_000 * 2);

        caliber.accountForPosition(acctInstruction);

        assertEq(caliber.getNetAum(), 0);
    }

    function test_GetNetAum_MultiplePositions() public withTokenAsBT(address(baseToken)) {
        uint256 aInputAmount = 5e20;
        uint256 bInputAmount = 1e18;

        uint256 expectedNetAUM;

        // increase accounting token position
        deal(address(accountingToken), address(caliber), aInputAmount, true);
        expectedNetAUM += aInputAmount;

        deal(address(baseToken), address(borrowModule), bInputAmount, true);

        // create debt position (should not modify net aum)
        ICaliber.Instruction memory borrowMgmtInstruction =
            _buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), bInputAmount);
        ICaliber.Instruction memory borrowAcctInstruction = _buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(borrowMgmtInstruction, borrowAcctInstruction);

        // create supply position (should not modify net aum)
        ICaliber.Instruction memory supplyMgmtInstruction =
            _buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), bInputAmount);
        ICaliber.Instruction memory supplyAcctInstruction = _buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(supplyMgmtInstruction, supplyAcctInstruction);

        ICaliber.Instruction[] memory batch = new ICaliber.Instruction[](2);
        batch[0] = supplyAcctInstruction;
        batch[1] = borrowAcctInstruction;
        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = LENDING_MARKET_POS_GROUP_ID;
        caliber.accountForPositionBatch(batch, groupIds);

        // check that AUM reflects all positions
        assertEq(caliber.getNetAum(), expectedNetAUM);

        // double borrowModule rate
        borrowModule.setRateBps(2 * 10_000);

        caliber.accountForPositionBatch(batch, groupIds);
        expectedNetAUM -= bInputAmount * PRICE_B_A;

        assertEq(caliber.getNetAum(), expectedNetAUM);

        // increase borrowModule rate
        borrowModule.setRateBps(1e2 * 10_000);

        caliber.accountForPositionBatch(batch, groupIds);
        expectedNetAUM = 0;

        assertEq(caliber.getNetAum(), expectedNetAUM);
    }
}
