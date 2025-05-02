// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IMachineFactory} from "src/interfaces/IMachineFactory.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {MachineFactory_Integration_Concrete_Test} from "../MachineFactory.t.sol";

contract CreatePreDepositVault_Integration_Concrete_Test is MachineFactory_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        IPreDepositVault.PreDepositVaultInitParams memory params;
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machineFactory.createPreDepositVault(params, address(0), address(0), "", "");
    }

    function test_CreatePreDepositVault() public {
        vm.expectEmit(false, false, false, false, address(machineFactory));
        emit IMachineFactory.PreDepositVaultDeployed(address(0), address(0));

        vm.prank(dao);
        preDepositVault = PreDepositVault(
            machineFactory.createPreDepositVault(
                IPreDepositVault.PreDepositVaultInitParams({
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialWhitelistMode: false,
                    initialRiskManager: address(0),
                    initialAuthority: address(accessManager)
                }),
                address(baseToken),
                address(accountingToken),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );

        assertTrue(machineFactory.isPreDepositVault(address(preDepositVault)));

        assertFalse(preDepositVault.migrated());

        vm.expectRevert(IPreDepositVault.NotMigrated.selector);
        preDepositVault.machine();

        assertEq(preDepositVault.depositToken(), address(baseToken));
        assertEq(preDepositVault.accountingToken(), address(accountingToken));
        assertEq(preDepositVault.authority(), address(accessManager));

        IMachineShare shareToken = IMachineShare(preDepositVault.shareToken());
        assertEq(shareToken.minter(), address(preDepositVault));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
    }
}
