// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract UpdateAndReportCaliberAUM_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_UpdateAndReportCaliberAUM() public {
        vm.startPrank(dao);
        oracleRegistry.setFeedStaleThreshold(address(aPriceFeed1), 1 days);
        oracleRegistry.setFeedStaleThreshold(address(bPriceFeed1), 1 days);
        vm.stopPrank();

        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](0);

        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), 0);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);

        skip(1 hours);

        uint256 inputAmount = 3e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        // check that accounting token is correctly accounted for in AUM
        uint256 expectedCaliberAUM = inputAmount;
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), expectedCaliberAUM);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);

        skip(1 hours);

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID);

        uint256 inputAmount2 = 2e18;
        deal(address(baseToken), address(caliber), inputAmount2, true);

        // check that base token is correctly accounted for in AUM
        expectedCaliberAUM += inputAmount2 * PRICE_B_A;
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), expectedCaliberAUM);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);

        skip(1 hours);

        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount2);
        vaultInstructions[1] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);

        // check that AUM remains the same after depositing baseToken into vault
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), expectedCaliberAUM);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);

        skip(1 hours);

        uint256 yield = 1e18;
        deal(address(baseToken), address(vault), inputAmount2 + yield, true);

        // check that AUM reflects vault yield
        accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = vaultInstructions[1];
        expectedCaliberAUM = inputAmount + vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A;
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), expectedCaliberAUM);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);
    }

    function test_RevertWhen_ProvidedInstructionInvalid()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vaultInstructions[1] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);

        // 1st instruction is not an accounting instruction
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.updateAndReportCaliberAUM(accountingInstructions);

        // 2nd instruction is not an accounting instruction
        accountingInstructions = new ICaliber.Instruction[](2);
        accountingInstructions[0] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        accountingInstructions[1] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.updateAndReportCaliberAUM(accountingInstructions);

        // position is a base token position
        accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = WeirollUtils._build4626AccountingInstruction(
            address(caliber), HUB_CALIBER_BASE_TOKEN_1_POS_ID, address(vault)
        );
        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        caliber.updateAndReportCaliberAUM(accountingInstructions);
    }

    function test_RevertGiven_PositionStale()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vaultInstructions[1] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);

        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](0);
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), inputAmount * PRICE_B_A);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);

        skip(DEFAULT_CALIBER_POS_STALE_THRESHOLD + 1);

        // check that AUM cannot be updated with stale position
        vm.expectRevert(abi.encodeWithSelector(ICaliber.PositionAccountingStale.selector, VAULT_POS_ID));
        caliber.updateAndReportCaliberAUM(accountingInstructions);

        // include accounting instruction and check that AUM can then be updated
        accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = vaultInstructions[1];
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), inputAmount * PRICE_B_A);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);
    }
}
