// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Machine} from "src/machine/Machine.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IHubDualMailbox} from "src/interfaces/IHubDualMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {Constants} from "src/libraries/Constants.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract Initialize_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_ProvidedAccountingTokenDecimalsTooLow() public {
        MockERC20 accountingToken2 =
            new MockERC20("Accounting Token 2", "AT2", Constants.MIN_ACCOUNTING_TOKEN_DECIMALS - 1);

        vm.expectRevert(IMachine.InvalidDecimals.selector);
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(IMachine.initialize, (_getMachineInitParams(address(accountingToken2))))
        );
    }

    function test_RevertWhen_ProvidedAccountingTokenDecimalsTooHigh() public {
        MockERC20 accountingToken2 =
            new MockERC20("Accounting Token 2", "AT2", Constants.MAX_ACCOUNTING_TOKEN_DECIMALS + 1);

        vm.expectRevert(IMachine.InvalidDecimals.selector);
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(IMachine.initialize, (_getMachineInitParams(address(accountingToken2))))
        );
    }

    function test_RevertWhen_ProvidedAccountingTokenNonPriceable() public {
        MockERC20 accountingToken2 = new MockERC20("Accounting Token 2", "AT2", 18);
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(IMachine.initialize, (_getMachineInitParams(address(accountingToken2))))
        );
    }

    function test_Initialize() public {
        machine = Machine(
            address(
                new BeaconProxy(
                    address(machineBeacon),
                    abi.encodeCall(IMachine.initialize, (_getMachineInitParams(address(accountingToken))))
                )
            )
        );
        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.authority(), address(accessManager));
        assertTrue(machine.isIdleToken(address(accountingToken)));

        assertEq(machine.getCalibersLength(), 1);

        address dualMailbox = machine.hubCaliberMailbox();
        address caliber = IHubDualMailbox(dualMailbox).caliber();
        assertEq(IHubDualMailbox(dualMailbox).machine(), address(machine));
        assertEq(ICaliber(caliber).mailbox(), dualMailbox);
    }

    function _getMachineInitParams(address accountingToken) internal view returns (IMachine.MachineInitParams memory) {
        return IMachine.MachineInitParams({
            accountingToken: accountingToken,
            initialMechanic: mechanic,
            initialSecurityCouncil: securityCouncil,
            depositor: machineDepositor,
            initialAuthority: address(accessManager),
            initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
            initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
            hubCaliberAccountingTokenPosID: HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID,
            hubCaliberPosStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
            hubCaliberAllowedInstrRoot: bytes32(""),
            hubCaliberTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
            hubCaliberMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
            hubCaliberMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
            hubCaliberMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
            depositorOnlyMode: false,
            shareTokenName: DEFAULT_MACHINE_SHARE_TOKEN_NAME,
            shareTokenSymbol: DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
        });
    }
}
