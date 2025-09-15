// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {PreDepositVault_Integration_Concrete_Test} from "../PreDepositVault.t.sol";

contract PreviewRedeem_Integration_Concrete_Test is PreDepositVault_Integration_Concrete_Test {
    function test_RevertGiven_VaultMigrated() public migrated {
        vm.expectRevert(Errors.Migrated.selector);
        preDepositVault.previewRedeem(1e18);
    }

    function test_PreviewRedeem() public view {
        uint256 inputAmount = 3e18;
        uint256 expectedShares = preDepositVault.previewRedeem(inputAmount);
        assertEq(expectedShares, inputAmount / PRICE_B_A);
    }
}
