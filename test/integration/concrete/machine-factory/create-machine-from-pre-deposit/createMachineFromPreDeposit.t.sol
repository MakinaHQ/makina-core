// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineFactory} from "src/interfaces/IMachineFactory.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {Machine} from "src/machine/Machine.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {MachineFactory_Integration_Concrete_Test} from "../MachineFactory.t.sol";

contract CreateMachineFromPreDeposit_Integration_Concrete_Test is MachineFactory_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machineFactory.createMachineFromPreDeposit(mParams, cParams, mgParams, address(0));
    }

    function test_RevertWhen_InvalidPreDepositVault() public {
        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;
        vm.expectRevert(IMachineFactory.NotPreDepositVault.selector);
        vm.prank(dao);
        machineFactory.createMachineFromPreDeposit(mParams, cParams, mgParams, address(0));
    }

    function test_CreateMachineFromPreDeposit() public {
        initialAllowedInstrRoot = bytes32("0x12345");

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

        vm.expectEmit(false, false, false, false, address(machineFactory));
        emit IMachineFactory.HubCaliberDeployed(address(0));

        vm.expectEmit(false, false, false, false, address(preDepositVault));
        emit IPreDepositVault.MigrateToMachine(address(0));

        vm.expectEmit(false, false, false, false, address(machineFactory));
        emit IMachineFactory.MachineDeployed(address(0), address(0), address(0));

        vm.prank(dao);
        machine = Machine(
            machineFactory.createMachineFromPreDeposit(
                IMachine.MachineInitParams({
                    accountingToken: address(accountingToken),
                    initialDepositor: machineDepositor,
                    initialRedeemer: machineRedeemer,
                    initialFeeManager: address(feeManager),
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialMaxFeeAccrualRate: DEFAULT_MACHINE_MAX_FEE_ACCRUAL_RATE,
                    initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT
                }),
                ICaliber.CaliberInitParams({
                    accountingToken: address(accountingToken),
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: initialAllowedInstrRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION,
                    initialFlashLoanModule: address(0)
                }),
                IMakinaGovernable.MakinaGovernableInitParams({
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialRiskManager: riskManager,
                    initialRiskManagerTimelock: riskManagerTimelock,
                    initialAuthority: address(accessManager)
                }),
                address(preDepositVault)
            )
        );

        assertTrue(preDepositVault.migrated());

        address caliber = machine.hubCaliber();

        assertTrue(machineFactory.isMachine(address(machine)));
        assertTrue(machineFactory.isCaliber(address(caliber)));

        assertEq(ICaliber(caliber).hubMachineEndpoint(), address(machine));

        assertEq(machine.registry(), address(hubRegistry));
        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.depositor(), machineDepositor);
        assertEq(machine.redeemer(), machineRedeemer);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.shareLimit(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(machine.authority(), address(accessManager));
        assertTrue(machine.isIdleToken(address(accountingToken)));
        assertEq(machine.getSpokeCalibersLength(), 0);

        IMachineShare shareToken = IMachineShare(machine.shareToken());
        assertEq(address(shareToken), preDepositVault.shareToken());
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
        assertEq(shareToken.totalSupply(), shares);

        assertTrue(machine.isIdleToken(address(baseToken)));
        assertEq(baseToken.balanceOf(address(preDepositVault)), 0);
        assertEq(baseToken.balanceOf(address(machine)), preDepositAmount);
    }
}
