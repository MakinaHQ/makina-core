// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract IsAccountingFresh_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_IsAccountingFresh() public withTokenAsBT(address(baseToken)) {
        assertTrue(caliber.isAccountingFresh());

        // open vault position
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vaultInstructions[1] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);

        assertTrue(caliber.isAccountingFresh());

        // skip past stale threshold
        skip(DEFAULT_CALIBER_POS_STALE_THRESHOLD + 1);

        assertFalse(caliber.isAccountingFresh());

        // account for vault position
        caliber.accountForPosition(vaultInstructions[1]);

        assertTrue(caliber.isAccountingFresh());
    }
}
