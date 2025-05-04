// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";

import {PreDepositVault_Integration_Concrete_Test} from "../PreDepositVault.t.sol";

contract SetPendingMachine_Integration_Concrete_Test is PreDepositVault_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotCoreFactory() public {
        vm.expectRevert(IPreDepositVault.NotFactory.selector);
        preDepositVault.setPendingMachine(address(0));
    }

    function test_RevertGiven_VaultMigrated() public migrated {
        vm.expectRevert(IPreDepositVault.Migrated.selector);
        preDepositVault.setPendingMachine(address(0));
    }

    function test_SetPendingMachine() public {
        address pendingMachineAddr = makeAddr("pendingMachine");
        vm.prank(address(hubCoreFactory));
        preDepositVault.setPendingMachine(pendingMachineAddr);

        vm.prank(pendingMachineAddr);
        preDepositVault.migrateToMachine();

        assertEq(preDepositVault.machine(), pendingMachineAddr);
    }
}
