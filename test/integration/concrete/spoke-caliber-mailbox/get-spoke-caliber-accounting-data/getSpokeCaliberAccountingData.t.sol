// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ISpokeCaliberMailbox} from "src/interfaces/ISpokeCaliberMailbox.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Integration_Concrete_Spoke_Test} from "../../IntegrationConcrete.t.sol";

contract GetSpokeCaliberAccountingData_Integration_Concrete_Test is Integration_Concrete_Spoke_Test {
    function setUp() public override {
        Integration_Concrete_Spoke_Test.setUp();
        _setUpCaliberMerkleRoot(caliber);
    }

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
        spokeCaliberMailbox.getSpokeCaliberAccountingData();
    }

    function test_GetPositionsValues() public withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID) {
        uint256 inputAmount = 3e18;

        // increase accounting token position
        deal(address(accountingToken), address(caliber), inputAmount, true);

        // check accounting token position is correctly accounted for in AUM
        ISpokeCaliberMailbox.SpokeCaliberAccountingData memory data =
            spokeCaliberMailbox.getSpokeCaliberAccountingData();
        assertEq(data.netAum, inputAmount);
        assertEq(data.positions.length, 2);
        assertEq(data.totalReceivedFromHM.length, 0);
        assertEq(data.totalSentToHM.length, 0);
        _checkEncodedCaliberPosValue(data.positions[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, inputAmount, false);
        _checkEncodedCaliberPosValue(data.positions[1], HUB_CALIBER_BASE_TOKEN_1_POS_ID, 0, false);

        skip(1 days);

        // check data is the same after a day
        data = spokeCaliberMailbox.getSpokeCaliberAccountingData();
        assertEq(data.netAum, inputAmount);
        assertEq(data.positions.length, 2);
        assertEq(data.totalReceivedFromHM.length, 0);
        assertEq(data.totalSentToHM.length, 0);
        _checkEncodedCaliberPosValue(data.positions[0], HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, inputAmount, false);
        _checkEncodedCaliberPosValue(data.positions[1], HUB_CALIBER_BASE_TOKEN_1_POS_ID, 0, false);
    }
}
