// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IHubCoreRegistry} from "src/interfaces/IHubCoreRegistry.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Machine} from "src/machine/Machine.sol";
import {MachineShare} from "src/machine/MachineShare.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract Initialize_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    PreDepositVault internal preDepositVault;
    MachineShare internal shareToken;

    address internal hubCaliberAddr;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();
        hubCaliberAddr = makeAddr("hubCaliber");
        shareToken =
            new MachineShare(DEFAULT_MACHINE_SHARE_TOKEN_NAME, DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL, address(this));
    }

    function test_RevertWhen_ProvidedAccountingTokenNonPriceable() public {
        MockERC20 accountingToken2 = new MockERC20("Accounting Token 2", "AT2", 18);

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(accountingToken2)));
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(
                IMachine.initialize,
                (
                    _getMachineInitParams(),
                    _getMakinaGovernableInitParams(),
                    address(0),
                    address(shareToken),
                    address(accountingToken2),
                    hubCaliberAddr
                )
            )
        );
    }

    function test_RevertWhen_ShareTokenOwnershipNonTransferred() public {
        machine = Machine(address(new BeaconProxy(address(machineBeacon), "")));

        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(machine))
        );
        IMachine(machine).initialize(
            _getMachineInitParams(),
            _getMakinaGovernableInitParams(),
            address(0),
            address(shareToken),
            address(accountingToken),
            hubCaliberAddr
        );
    }

    function test_Initialize_WithoutPreDeposit() public {
        machine = Machine(address(new BeaconProxy(address(machineBeacon), "")));
        shareToken.transferOwnership(address(machine));

        IMachine(machine).initialize(
            _getMachineInitParams(),
            _getMakinaGovernableInitParams(),
            address(0),
            address(shareToken),
            address(accountingToken),
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
        assertEq(machine.getIdleTokensLength(), 1);
        assertEq(machine.getIdleToken(0), address(accountingToken));
        assertEq(shareToken.owner(), address(machine));
        assertEq(machine.getSpokeCalibersLength(), 0);
        assertEq(machine.hubCaliber(), hubCaliberAddr);
    }

    function test_Initialize_WithPreDeposit_ZeroBalance() public {
        machine = Machine(address(new BeaconProxy(address(machineBeacon), "")));

        // deploy caliber to be called in machine initializer
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams = _getMakinaGovernableInitParams();
        hubCaliberAddr = address(
            new BeaconProxy(
                IHubCoreRegistry(hubCoreRegistry).caliberBeacon(),
                abi.encodeCall(ICaliber.initialize, (cParams, address(accountingToken), address(machine)))
            )
        );

        vm.prank(dao);
        preDepositVault = PreDepositVault(
            hubCoreFactory.createPreDepositVault(
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

        vm.prank(address(hubCoreFactory));
        preDepositVault.setPendingMachine(address(machine));

        shareToken = MachineShare(preDepositVault.shareToken());

        vm.prank(address(preDepositVault));
        shareToken.transferOwnership(address(machine));

        IMachine(machine).initialize(
            _getMachineInitParams(),
            mgParams,
            address(preDepositVault),
            address(shareToken),
            address(accountingToken),
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
        assertFalse(machine.isIdleToken(address(baseToken)));
        assertEq(machine.getIdleTokensLength(), 1);
        assertEq(machine.getIdleToken(0), address(accountingToken));
        assertEq(shareToken.owner(), address(machine));
        assertEq(machine.getSpokeCalibersLength(), 0);
        assertEq(machine.hubCaliber(), hubCaliberAddr);

        assertEq(address(shareToken), machine.shareToken());
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
        assertEq(shareToken.totalSupply(), 0);

        assertEq(baseToken.balanceOf(address(preDepositVault)), 0);
        assertEq(baseToken.balanceOf(address(machine)), 0);
    }

    function test_Initialize_WithPreDeposit_PositiveBalance() public {
        machine = Machine(address(new BeaconProxy(address(machineBeacon), "")));

        // deploy caliber to be called in machine initializer
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams = _getMakinaGovernableInitParams();
        hubCaliberAddr = address(
            new BeaconProxy(
                IHubCoreRegistry(hubCoreRegistry).caliberBeacon(),
                abi.encodeCall(ICaliber.initialize, (cParams, address(accountingToken), address(machine)))
            )
        );

        vm.prank(dao);
        preDepositVault = PreDepositVault(
            hubCoreFactory.createPreDepositVault(
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

        // deposit funds into pre-deposit vault
        uint256 preDepositAmount = 1e18;
        deal(address(baseToken), address(this), preDepositAmount);
        baseToken.approve(address(preDepositVault), preDepositAmount);
        uint256 shares = preDepositVault.deposit(preDepositAmount, address(this), 0, 0);

        vm.prank(address(hubCoreFactory));
        preDepositVault.setPendingMachine(address(machine));

        shareToken = MachineShare(preDepositVault.shareToken());

        vm.prank(address(preDepositVault));
        shareToken.transferOwnership(address(machine));

        IMachine(machine).initialize(
            _getMachineInitParams(),
            mgParams,
            address(preDepositVault),
            address(shareToken),
            address(accountingToken),
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
        assertTrue(machine.isIdleToken(address(baseToken)));
        assertEq(machine.getIdleTokensLength(), 2);
        assertEq(machine.getIdleToken(0), address(accountingToken));
        assertEq(machine.getIdleToken(1), address(baseToken));
        assertEq(shareToken.owner(), address(machine));
        assertEq(machine.getSpokeCalibersLength(), 0);
        assertEq(machine.hubCaliber(), hubCaliberAddr);

        assertEq(address(shareToken), machine.shareToken());
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
        assertEq(shareToken.totalSupply(), shares);

        assertEq(baseToken.balanceOf(address(preDepositVault)), 0);
        assertEq(baseToken.balanceOf(address(machine)), preDepositAmount);
    }

    function _getMachineInitParams() internal view returns (IMachine.MachineInitParams memory) {
        return IMachine.MachineInitParams({
            initialDepositor: machineDepositor,
            initialRedeemer: machineRedeemer,
            initialFeeManager: address(feeManager),
            initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
            initialMaxFixedFeeAccrualRate: DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE,
            initialMaxPerfFeeAccrualRate: DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE,
            initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
            initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
            initialMaxSharePriceChangeRate: DEFAULT_MACHINE_MAX_SHARE_PRICE_CHANGE_RATE
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
            initialAuthority: address(accessManager),
            initialRestrictedAccountingMode: false
        });
    }
}
