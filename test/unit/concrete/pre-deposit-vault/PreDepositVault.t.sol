// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

abstract contract PreDepositVault_Unit_Concrete_Test is Unit_Concrete_Hub_Test {
    PreDepositVault public preDepositVault;

    function setUp() public virtual override {
        Unit_Concrete_Hub_Test.setUp();

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

    modifier migrated() {
        address newMachineAddr = makeAddr("newMachine");

        vm.prank(address(hubCoreFactory));
        preDepositVault.setPendingMachine(newMachineAddr);

        vm.prank(newMachineAddr);
        preDepositVault.migrateToMachine();

        _;
    }
}

contract Getters_Setters_PreDepositVault_Unit_Concrete_Test is PreDepositVault_Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(preDepositVault.registry(), address(hubCoreRegistry));
        assertEq(preDepositVault.totalAssets(), 0);
        assertEq(preDepositVault.depositToken(), address(baseToken));
        assertEq(preDepositVault.accountingToken(), address(accountingToken));
        assertNotEq(preDepositVault.shareToken(), address(0));
        assertEq(preDepositVault.shareLimit(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(preDepositVault.maxDeposit(), type(uint256).max);
        assertFalse(preDepositVault.whitelistMode());
        assertFalse(preDepositVault.isWhitelistedUser(address(0)));
        assertEq(preDepositVault.riskManager(), riskManager);
        assertEq(preDepositVault.authority(), address(accessManager));
        assertFalse(preDepositVault.migrated());
    }

    function test_SetShareLimit_RevertWhen_CallerNotRiskManager() public {
        vm.expectRevert(IPreDepositVault.UnauthorizedCaller.selector);
        preDepositVault.setShareLimit(0);
    }

    function test_SetShareLimit_RevertGiven_VaultMigrated() public migrated {
        vm.expectRevert(IPreDepositVault.Migrated.selector);
        vm.prank(riskManager);
        preDepositVault.setShareLimit(0);
    }

    function test_SetShareLimit() public {
        uint256 newShareLimit = 1000;

        vm.expectEmit(true, true, false, false);
        emit IPreDepositVault.ShareLimitChanged(DEFAULT_MACHINE_SHARE_LIMIT, newShareLimit);
        vm.prank(riskManager);
        preDepositVault.setShareLimit(newShareLimit);

        assertEq(preDepositVault.shareLimit(), newShareLimit);
    }

    function test_SetRiskManager_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        preDepositVault.setRiskManager(address(0));
    }

    function test_SetRiskManager_RevertGiven_VaultMigrated() public migrated {
        vm.expectRevert(IPreDepositVault.Migrated.selector);
        vm.prank(dao);
        preDepositVault.setRiskManager(address(0));
    }

    function test_SetRiskManager() public {
        address newRiskManager = makeAddr("riskManager");

        vm.expectEmit(true, true, false, false);
        emit IPreDepositVault.RiskManagerChanged(riskManager, newRiskManager);
        vm.prank(address(dao));
        preDepositVault.setRiskManager(newRiskManager);

        assertEq(preDepositVault.riskManager(), newRiskManager);
    }

    function test_SetWhitelistedUsers_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        preDepositVault.setWhitelistedUsers(new address[](0), true);
    }

    function test_SetWhitelistedUsers_RevertGiven_VaultMigrated() public migrated {
        vm.expectRevert(IPreDepositVault.Migrated.selector);
        vm.prank(dao);
        preDepositVault.setWhitelistedUsers(new address[](0), true);
    }

    function test_SetWhitelistedUsers() public {
        address[] memory users = new address[](2);
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");

        vm.expectEmit(true, true, false, false, address(preDepositVault));
        emit IPreDepositVault.UserWhitelistingChanged(users[0], true);

        vm.expectEmit(true, true, false, false, address(preDepositVault));
        emit IPreDepositVault.UserWhitelistingChanged(users[1], true);

        vm.prank(dao);
        preDepositVault.setWhitelistedUsers(users, true);

        assertTrue(preDepositVault.isWhitelistedUser(users[0]));
        assertTrue(preDepositVault.isWhitelistedUser(users[1]));
    }

    function test_SetWhitelistMode_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        preDepositVault.setWhitelistMode(true);
    }

    function test_SetWhitelistMode_RevertGiven_VaultMigrated() public migrated {
        vm.expectRevert(IPreDepositVault.Migrated.selector);
        vm.prank(dao);
        preDepositVault.setWhitelistMode(true);
    }

    function test_SetWhitelistMode() public {
        vm.expectEmit(true, false, false, false, address(preDepositVault));
        emit IPreDepositVault.WhitelistModeChanged(true);
        vm.prank(dao);
        preDepositVault.setWhitelistMode(true);
        assertTrue(preDepositVault.whitelistMode());
    }
}
