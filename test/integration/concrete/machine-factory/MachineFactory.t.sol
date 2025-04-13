// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineFactory} from "src/interfaces/IMachineFactory.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {Machine} from "src/machine/Machine.sol";

import {Integration_Concrete_Hub_Test} from "../IntegrationConcrete.t.sol";

contract MachineFactory_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    bytes32 private initialAllowedInstrRoot;

    function test_Getters() public view {
        assertEq(machineFactory.registry(), address(hubRegistry));
        assertFalse(machineFactory.isMachine(address(0)));
        assertFalse(machineFactory.isCaliber(address(0)));
    }

    function test_RevertWhen_CallerWithoutRole() public {
        IMachine.MachineInitParams memory params;
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machineFactory.createMachine(params, "", "");
    }

    function test_DeployMachine() public {
        initialAllowedInstrRoot = bytes32("0x12345");

        vm.expectEmit(false, false, false, false, address(machineFactory));
        emit IMachineFactory.MachineDeployed(address(0), address(0), address(0));
        vm.prank(dao);
        machine = Machine(
            machineFactory.createMachine(
                IMachine.MachineInitParams({
                    accountingToken: address(accountingToken),
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialAuthority: address(accessManager),
                    initialDepositor: machineDepositor,
                    initialRedeemer: machineRedeemer,
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    hubCaliberPosStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    hubCaliberAllowedInstrRoot: initialAllowedInstrRoot,
                    hubCaliberTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    hubCaliberMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    hubCaliberMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    hubCaliberMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    hubCaliberInitialFlashLoanModule: address(0)
                }),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );
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
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
    }
}
