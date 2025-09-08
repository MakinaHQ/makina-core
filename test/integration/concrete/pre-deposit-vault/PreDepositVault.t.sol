// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {Integration_Concrete_Hub_Test} from "../IntegrationConcrete.t.sol";

abstract contract PreDepositVault_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    PreDepositVault public preDepositVault;

    address public newMachineAddr;

    function setUp() public virtual override {
        Integration_Concrete_Hub_Test.setUp();

        vm.prank(dao);
        preDepositVault = PreDepositVault(
            hubCoreFactory.createPreDepositVault(
                IPreDepositVault.PreDepositVaultInitParams({
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialWhitelistMode: false,
                    initialRiskManager: riskManager,
                    initialAuthority: address(accessManager)
                }),
                address(baseToken),
                address(accountingToken),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );
    }

    modifier whitelistMode() {
        vm.prank(riskManager);
        preDepositVault.setWhitelistMode(true);

        _;
    }

    modifier whitelistedUser(address user) {
        address[] memory whitelist = new address[](1);
        whitelist[0] = user;
        vm.prank(riskManager);
        preDepositVault.setWhitelistedUsers(whitelist, true);

        _;
    }

    modifier migrated() {
        newMachineAddr = makeAddr("newMachine");

        vm.prank(address(hubCoreFactory));
        preDepositVault.setPendingMachine(newMachineAddr);

        vm.prank(newMachineAddr);
        preDepositVault.migrateToMachine();

        _;
    }
}
