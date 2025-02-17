// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IHubDualMailbox} from "src/interfaces/IHubDualMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineFactory} from "src/interfaces/IMachineFactory.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {Machine} from "src/machine/Machine.sol";

import {Integration_Concrete_Test} from "../IntegrationConcrete.t.sol";

contract MachineFactory_Integration_Concrete_Test is Integration_Concrete_Test {
    bytes32 private initialAllowedInstrRoot;

    function test_Getters() public view {
        assertEq(machineFactory.registry(), address(hubRegistry));
        assertEq(machineFactory.isMachine(address(0)), false);
    }

    function test_RevertWhen_CallerWithoutRole() public {
        IMachine.MachineInitParams memory params;
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machineFactory.deployMachine(params);
    }

    function test_DeployMachine() public {
        initialAllowedInstrRoot = bytes32("0x12345");

        vm.expectEmit(false, false, false, false, address(machineFactory));
        emit IMachineFactory.MachineDeployed(address(0));
        vm.prank(dao);
        machine = Machine(
            machineFactory.deployMachine(
                IMachine.MachineInitParams({
                    accountingToken: address(accountingToken),
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialAuthority: address(accessManager),
                    depositor: machineDepositor,
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    hubCaliberAccountingTokenPosID: HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID,
                    hubCaliberPosStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    hubCaliberAllowedInstrRoot: initialAllowedInstrRoot,
                    hubCaliberTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    hubCaliberMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    hubCaliberMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    hubCaliberMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    depositorOnlyMode: false,
                    shareTokenName: DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                    shareTokenSymbol: DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
                })
            )
        );
        assertEq(machineFactory.isMachine(address(machine)), true);

        assertEq(machine.registry(), address(hubRegistry));
        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.shareLimit(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(machine.authority(), address(accessManager));
        assertTrue(machine.isIdleToken(address(accountingToken)));

        IMachineShare shareToken = IMachineShare(machine.shareToken());
        assertEq(shareToken.machine(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);

        assertEq(machine.getCalibersLength(), 1);

        address hubDualMailbox = machine.getMailbox(block.chainid);
        address caliber = IHubDualMailbox(hubDualMailbox).caliber();
        assertEq(IHubDualMailbox(hubDualMailbox).machine(), address(machine));
        assertEq(ICaliber(caliber).mailbox(), hubDualMailbox);
    }
}
