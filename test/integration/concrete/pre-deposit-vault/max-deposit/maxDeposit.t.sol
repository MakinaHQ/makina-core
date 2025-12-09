// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PreDepositVault_Integration_Concrete_Test} from "../PreDepositVault.t.sol";

contract MaxDeposit_Integration_Concrete_Test is PreDepositVault_Integration_Concrete_Test {
    function test_MaxDeposit_VaultMigrated() public migrated {
        assertEq(preDepositVault.maxDeposit(), 0);
    }

    function test_MaxDeposit_InfiniteShareLimit() public {
        vm.prank(riskManager);
        preDepositVault.setShareLimit(type(uint256).max);

        assertEq(preDepositVault.maxDeposit(), type(uint256).max);
    }

    function test_MaxDeposit_LimitedShares() public {
        vm.prank(riskManager);
        preDepositVault.setShareLimit(100e18);

        // should hold in initial state
        assertEq(preDepositVault.maxDeposit(), 100e18 / PRICE_B_A);
    }

    function test_MaxDeposit_SupplyExceedsLimit() public {
        deal(address(baseToken), address(this), 100e18);
        baseToken.approve(address(preDepositVault), 100e18);
        preDepositVault.deposit(100e18, address(this), 0, 0);

        vm.prank(riskManager);
        preDepositVault.setShareLimit(1);

        assertEq(preDepositVault.maxDeposit(), 0);
    }
}
