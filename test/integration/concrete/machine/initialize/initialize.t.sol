// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IHubRegistry} from "src/interfaces/IHubRegistry.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Machine} from "src/machine/Machine.sol";
import {MachineShare} from "src/machine/MachineShare.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract Initialize_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    PreDepositVault public preDepositVault;
    MachineShare public shareToken;

    address public hubCaliberAddr;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();
        hubCaliberAddr = makeAddr("hubCaliber");
        shareToken = new MachineShare(
            DEFAULT_MACHINE_SHARE_TOKEN_NAME,
            DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL,
            Constants.SHARE_TOKEN_DECIMALS,
            address(this)
        );
    }

    function test_RevertWhen_ProvidedATDecimalsTooLow() public {
        MockERC20 accountingToken2 =
            new MockERC20("Accounting Token 2", "AT2", Constants.MIN_ACCOUNTING_TOKEN_DECIMALS - 1);

        vm.expectRevert(IMachine.InvalidDecimals.selector);
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(
                IMachine.initialize,
                (
                    _getMachineInitParams(address(accountingToken2)),
                    _getMakinaGovernableInitParams(),
                    address(0),
                    address(shareToken),
                    hubCaliberAddr
                )
            )
        );
    }

    function test_RevertWhen_ProvidedATDecimalsTooHigh() public {
        MockERC20 accountingToken2 =
            new MockERC20("Accounting Token 2", "AT2", Constants.MAX_ACCOUNTING_TOKEN_DECIMALS + 1);

        vm.expectRevert(IMachine.InvalidDecimals.selector);
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(
                IMachine.initialize,
                (
                    _getMachineInitParams(address(accountingToken2)),
                    _getMakinaGovernableInitParams(),
                    address(0),
                    address(shareToken),
                    hubCaliberAddr
                )
            )
        );
    }

    function test_RevertWhen_ProvidedAccountingTokenNonPriceable() public {
        MockERC20 accountingToken2 = new MockERC20("Accounting Token 2", "AT2", 18);

        vm.expectRevert(
            abi.encodeWithSelector(IOracleRegistry.PriceFeedRouteNotRegistered.selector, address(accountingToken2))
        );
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(
                IMachine.initialize,
                (
                    _getMachineInitParams(address(accountingToken2)),
                    _getMakinaGovernableInitParams(),
                    address(0),
                    address(shareToken),
                    hubCaliberAddr
                )
            )
        );
    }

    function test_RevertWhen_ShareTokenMismatch() public {
        machine = Machine(address(new BeaconProxy(address(machineBeacon), "")));

        vm.prank(dao);
        preDepositVault = PreDepositVault(
            machineFactory.createPreDepositVault(
                IPreDepositVault.PreDepositVaultInitParams({
                    depositToken: address(baseToken),
                    accountingToken: address(accountingToken),
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialWhitelistMode: false,
                    initialRiskManager: address(0),
                    initialAuthority: address(accessManager)
                }),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );

        vm.expectRevert(IMachine.PreDepositVaultMismatch.selector);
        IMachine(machine).initialize(
            _getMachineInitParams(address(accountingToken)),
            _getMakinaGovernableInitParams(),
            address(preDepositVault),
            address(shareToken),
            hubCaliberAddr
        );
    }

    function test_RevertWhen_AccountingTokenMismatch() public {
        machine = Machine(address(new BeaconProxy(address(machineBeacon), "")));

        vm.prank(dao);
        preDepositVault = PreDepositVault(
            machineFactory.createPreDepositVault(
                IPreDepositVault.PreDepositVaultInitParams({
                    depositToken: address(baseToken),
                    accountingToken: address(accountingToken),
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialWhitelistMode: false,
                    initialRiskManager: address(0),
                    initialAuthority: address(accessManager)
                }),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );

        shareToken = MachineShare(preDepositVault.shareToken());

        vm.expectRevert(IMachine.PreDepositVaultMismatch.selector);
        IMachine(machine).initialize(
            _getMachineInitParams(address(baseToken)),
            _getMakinaGovernableInitParams(),
            address(preDepositVault),
            address(shareToken),
            hubCaliberAddr
        );
    }

    function test_RevertWhen_ShareTokenOwnershipNonTransferred() public {
        machine = Machine(address(new BeaconProxy(address(machineBeacon), "")));

        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(machine))
        );
        IMachine(machine).initialize(
            _getMachineInitParams(address(accountingToken)),
            _getMakinaGovernableInitParams(),
            address(0),
            address(shareToken),
            hubCaliberAddr
        );
    }

    function test_Initialize_WithoutPreDeposit() public {
        machine = Machine(address(new BeaconProxy(address(machineBeacon), "")));
        shareToken.transferOwnership(address(machine));

        IMachine(machine).initialize(
            _getMachineInitParams(address(accountingToken)),
            _getMakinaGovernableInitParams(),
            address(0),
            address(shareToken),
            hubCaliberAddr
        );

        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.depositor(), machineDepositor);
        assertEq(machine.redeemer(), machineRedeemer);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.authority(), address(accessManager));
        assertTrue(machine.isIdleToken(address(accountingToken)));
        assertEq(shareToken.owner(), address(machine));
        assertEq(machine.getSpokeCalibersLength(), 0);
        assertEq(machine.hubCaliber(), hubCaliberAddr);
    }

    function test_Initialize_WithPreDeposit() public {
        machine = Machine(address(new BeaconProxy(address(machineBeacon), "")));

        // deploy caliber to be called in machine initializer
        ICaliber.CaliberInitParams memory cParams;
        cParams.accountingToken = address(accountingToken);
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams = _getMakinaGovernableInitParams();
        hubCaliberAddr = address(
            new BeaconProxy(
                IHubRegistry(hubRegistry).caliberBeacon(),
                abi.encodeCall(ICaliber.initialize, (cParams, mgParams, address(machine)))
            )
        );

        vm.prank(dao);
        preDepositVault = PreDepositVault(
            machineFactory.createPreDepositVault(
                IPreDepositVault.PreDepositVaultInitParams({
                    depositToken: address(baseToken),
                    accountingToken: address(accountingToken),
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialWhitelistMode: false,
                    initialRiskManager: address(0),
                    initialAuthority: address(accessManager)
                }),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );

        uint256 preDepositAmount = 1e18;
        deal(address(baseToken), address(this), preDepositAmount);
        baseToken.approve(address(preDepositVault), preDepositAmount);
        uint256 shares = preDepositVault.deposit(preDepositAmount, address(this), 0);

        vm.prank(address(machineFactory));
        preDepositVault.setPendingMachine(address(machine));

        shareToken = MachineShare(preDepositVault.shareToken());

        vm.prank(address(preDepositVault));
        shareToken.transferOwnership(address(machine));

        IMachine(machine).initialize(
            _getMachineInitParams(address(accountingToken)),
            mgParams,
            address(preDepositVault),
            address(shareToken),
            hubCaliberAddr
        );

        assertTrue(preDepositVault.migrated());

        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.depositor(), machineDepositor);
        assertEq(machine.redeemer(), machineRedeemer);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.authority(), address(accessManager));
        assertTrue(machine.isIdleToken(address(accountingToken)));
        assertEq(shareToken.owner(), address(machine));
        assertEq(machine.getSpokeCalibersLength(), 0);
        assertEq(machine.hubCaliber(), hubCaliberAddr);

        assertEq(address(shareToken), machine.shareToken());
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
        assertEq(shareToken.totalSupply(), shares);

        assertTrue(machine.isIdleToken(address(baseToken)));
        assertEq(baseToken.balanceOf(address(preDepositVault)), 0);
        assertEq(baseToken.balanceOf(address(machine)), preDepositAmount);
    }

    function _getMachineInitParams(address accountingToken) internal view returns (IMachine.MachineInitParams memory) {
        return IMachine.MachineInitParams({
            accountingToken: accountingToken,
            initialDepositor: machineDepositor,
            initialRedeemer: machineRedeemer,
            initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
            initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT
        });
    }

    function _getMakinaGovernableInitParams()
        internal
        view
        returns (IMakinaGovernable.MakinaGovernableInitParams memory)
    {
        return IMakinaGovernable.MakinaGovernableInitParams({
            initialMechanic: mechanic,
            initialSecurityCouncil: securityCouncil,
            initialRiskManager: riskManager,
            initialRiskManagerTimelock: riskManagerTimelock,
            initialAuthority: address(accessManager)
        });
    }
}
