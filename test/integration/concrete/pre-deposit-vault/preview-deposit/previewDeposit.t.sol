// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {PreDepositVault_Integration_Concrete_Test} from "../PreDepositVault.t.sol";

contract PreviewDeposit_Integration_Concrete_Test is PreDepositVault_Integration_Concrete_Test {
    function test_RevertGiven_VaultMigrated() public migrated {
        vm.expectRevert(Errors.Migrated.selector);
        preDepositVault.previewDeposit(1e18);
    }

    function test_PreviewDeposit() public view {
        uint256 inputAmount = 3e18;
        uint256 expectedShares = preDepositVault.previewDeposit(inputAmount);
        assertEq(expectedShares, inputAmount * PRICE_B_A);
    }
}
