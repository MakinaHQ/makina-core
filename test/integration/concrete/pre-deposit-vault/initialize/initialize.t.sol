// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MachineShare} from "src/machine/MachineShare.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {PreDepositVault_Integration_Concrete_Test} from "../PreDepositVault.t.sol";

contract Initialize_Integration_Concrete_Test is PreDepositVault_Integration_Concrete_Test {
    MachineShare internal shareToken;

    function setUp() public override {
        PreDepositVault_Integration_Concrete_Test.setUp();

        shareToken =
            new MachineShare(DEFAULT_MACHINE_SHARE_TOKEN_NAME, DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL, address(this));
    }

    function test_RevertWhen_ProvidedAccountingTokenNonPriceable() public {
        MockERC20 accountingToken2 = new MockERC20("Accounting Token 2", "AT2", 18);

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(accountingToken2)));
        new BeaconProxy(
            address(preDepositVaultBeacon),
            abi.encodeCall(
                IPreDepositVault.initialize,
                (_getPreDepositVaultInitParams(), address(shareToken), address(baseToken), address(accountingToken2))
            )
        );
    }

    function test_RevertWhen_ProvidedDepositTokenNonPriceable() public {
        MockERC20 baseToken2 = new MockERC20("Deposit Token 2", "DT2", 18);

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(baseToken2)));
        new BeaconProxy(
            address(preDepositVaultBeacon),
            abi.encodeCall(
                IPreDepositVault.initialize,
                (_getPreDepositVaultInitParams(), address(shareToken), address(baseToken2), address(accountingToken))
            )
        );
    }

    function test_RevertWhen_ShareTokenOwnershipNonTransferred() public {
        preDepositVault = PreDepositVault(address(new BeaconProxy(address(preDepositVaultBeacon), "")));

        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(preDepositVault))
        );
        IPreDepositVault(preDepositVault).initialize(
            _getPreDepositVaultInitParams(), address(shareToken), address(baseToken), address(accountingToken)
        );
    }

    function test_Initialize() public {
        preDepositVault = PreDepositVault(address(new BeaconProxy(address(preDepositVaultBeacon), "")));

        shareToken.transferOwnership(address(preDepositVault));

        IPreDepositVault(preDepositVault).initialize(
            _getPreDepositVaultInitParams(), address(shareToken), address(baseToken), address(accountingToken)
        );

        assertFalse(preDepositVault.migrated());

        vm.expectRevert(Errors.NotMigrated.selector);
        preDepositVault.machine();

        assertEq(preDepositVault.depositToken(), address(baseToken));
        assertEq(preDepositVault.accountingToken(), address(accountingToken));
        assertEq(preDepositVault.shareToken(), address(shareToken));
        assertEq(machine.authority(), address(accessManager));
        assertEq(shareToken.owner(), address(preDepositVault));
    }

    function _getPreDepositVaultInitParams()
        internal
        view
        returns (IPreDepositVault.PreDepositVaultInitParams memory)
    {
        return IPreDepositVault.PreDepositVaultInitParams({
            initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
            initialWhitelistMode: false,
            initialRiskManager: address(0),
            initialAuthority: address(accessManager)
        });
    }
}
