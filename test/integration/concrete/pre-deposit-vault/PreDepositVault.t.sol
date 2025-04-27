// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {Integration_Concrete_Hub_Test} from "../IntegrationConcrete.t.sol";

abstract contract PreDepositVault_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    PreDepositVault public preDepositVault;

    address public newMachineAddr;

    address public riskManager;

    function setUp() public virtual override {
        Integration_Concrete_Hub_Test.setUp();

        riskManager = makeAddr("riskManager");

        vm.prank(dao);
        preDepositVault = PreDepositVault(
            machineFactory.createPreDepositVault(
                IPreDepositVault.PreDepositVaultInitParams({
                    depositToken: address(baseToken),
                    accountingToken: address(accountingToken),
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialWhitelistMode: false,
                    initialRiskManager: riskManager,
                    initialAuthority: address(accessManager)
                }),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );
    }

    modifier whitelistMode() {
        vm.prank(dao);
        preDepositVault.setWhitelistMode(true);

        _;
    }

    modifier migrated() {
        newMachineAddr = makeAddr("newMachine");

        vm.prank(address(machineFactory));
        preDepositVault.setPendingMachine(newMachineAddr);

        vm.prank(newMachineAddr);
        preDepositVault.migrateToMachine();

        _;
    }
}
