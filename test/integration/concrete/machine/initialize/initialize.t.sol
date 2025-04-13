// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Machine} from "src/machine/Machine.sol";
import {MachineShare} from "src/machine/MachineShare.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {Constants} from "src/libraries/Constants.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract Initialize_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    MachineShare public shareToken;

    address public hubCaliberAddr;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();
        shareToken = new MachineShare(
            DEFAULT_MACHINE_SHARE_TOKEN_NAME,
            DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL,
            Constants.SHARE_TOKEN_DECIMALS,
            address(this)
        );
        hubCaliberAddr = makeAddr("hubCaliber");
    }

    function test_RevertWhen_ProvidedATDecimalsTooLow() public {
        MockERC20 accountingToken2 =
            new MockERC20("Accounting Token 2", "AT2", Constants.MIN_ACCOUNTING_TOKEN_DECIMALS - 1);

        vm.expectRevert(IMachine.InvalidDecimals.selector);
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(
                IMachine.initialize,
                (_getMachineInitParams(address(accountingToken2)), address(shareToken), hubCaliberAddr)
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
                (_getMachineInitParams(address(accountingToken2)), address(shareToken), hubCaliberAddr)
            )
        );
    }

    function test_RevertWhen_ProvidedATDecimalsLowerThanSTDecimals() public {
        MockERC20 accountingToken2 = new MockERC20("Accounting Token 2", "AT2", Constants.MAX_ACCOUNTING_TOKEN_DECIMALS);
        MachineShare shareToken2 = new MachineShare(
            DEFAULT_MACHINE_SHARE_TOKEN_NAME,
            DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL,
            Constants.MAX_ACCOUNTING_TOKEN_DECIMALS - 1,
            address(this)
        );

        vm.expectRevert(IMachine.InvalidDecimals.selector);
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(
                IMachine.initialize,
                (_getMachineInitParams(address(accountingToken2)), address(shareToken2), hubCaliberAddr)
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
                (_getMachineInitParams(address(accountingToken2)), address(shareToken), hubCaliberAddr)
            )
        );
    }

    function test_Initialize() public {
        machine = Machine(address(new BeaconProxy(address(machineBeacon), "")));
        shareToken.transferOwnership(address(machine));
        IMachine(machine).initialize(
            _getMachineInitParams(address(accountingToken)), address(shareToken), hubCaliberAddr
        );

        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.depositor(), machineDepositor);
        assertEq(machine.redeemer(), machineRedeemer);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.authority(), address(accessManager));
        assertTrue(machine.isIdleToken(address(accountingToken)));
        assertEq(machine.getSpokeCalibersLength(), 0);
        assertEq(machine.hubCaliber(), hubCaliberAddr);
    }

    function _getMachineInitParams(address accountingToken) internal view returns (IMachine.MachineInitParams memory) {
        return IMachine.MachineInitParams({
            accountingToken: accountingToken,
            initialMechanic: mechanic,
            initialSecurityCouncil: securityCouncil,
            initialDepositor: machineDepositor,
            initialRedeemer: machineRedeemer,
            initialAuthority: address(accessManager),
            initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
            initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
            hubCaliberPosStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
            hubCaliberAllowedInstrRoot: bytes32(""),
            hubCaliberTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
            hubCaliberMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
            hubCaliberMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
            hubCaliberMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
            hubCaliberInitialFlashLoanModule: address(0)
        });
    }
}
