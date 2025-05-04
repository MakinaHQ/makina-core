// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IHubCoreFactory} from "src/interfaces/IHubCoreFactory.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {Machine} from "src/machine/Machine.sol";

import {HubCoreFactory_Integration_Concrete_Test} from "../HubCoreFactory.t.sol";

contract CreateMachine_Integration_Concrete_Test is HubCoreFactory_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubCoreFactory.createMachine(mParams, cParams, mgParams, address(0), "", "");
    }

    function test_CreateMachine() public {
        initialAllowedInstrRoot = bytes32("0x12345");

        vm.expectEmit(false, false, false, false, address(hubCoreFactory));
        emit IHubCoreFactory.HubCaliberDeployed(address(0));

        vm.expectEmit(false, false, false, false, address(hubCoreFactory));
        emit IHubCoreFactory.MachineDeployed(address(0), address(0), address(0));

        vm.prank(dao);
        machine = Machine(
            hubCoreFactory.createMachine(
                IMachine.MachineInitParams({
                    initialDepositor: machineDepositor,
                    initialRedeemer: machineRedeemer,
                    initialFeeManager: address(feeManager),
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialMaxFeeAccrualRate: DEFAULT_MACHINE_MAX_FEE_ACCRUAL_RATE,
                    initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT
                }),
                ICaliber.CaliberInitParams({
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: initialAllowedInstrRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION
                }),
                IMakinaGovernable.MakinaGovernableInitParams({
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialRiskManager: riskManager,
                    initialRiskManagerTimelock: riskManagerTimelock,
                    initialAuthority: address(accessManager)
                }),
                address(accountingToken),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );
        address caliber = machine.hubCaliber();

        assertTrue(hubCoreFactory.isMachine(address(machine)));
        assertTrue(hubCoreFactory.isCaliber(address(caliber)));

        assertEq(ICaliber(caliber).hubMachineEndpoint(), address(machine));

        assertEq(machine.registry(), address(hubCoreRegistry));
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
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
    }
}
