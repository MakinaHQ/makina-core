// SPDX-License-Identifier: BUSL-1.1
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
        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertTrue(caliber.isAccountingFresh());

        // skip past stale threshold
        skip(DEFAULT_CALIBER_POS_STALE_THRESHOLD);

        assertFalse(caliber.isAccountingFresh());

        // account for vault position
        caliber.accountForPosition(acctInstruction);

        assertTrue(caliber.isAccountingFresh());
    }
}
