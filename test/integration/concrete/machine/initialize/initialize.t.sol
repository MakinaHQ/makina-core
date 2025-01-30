// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {Constants} from "src/libraries/Constants.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract Initialize_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_cannotDeployMachineWithAccoutingTokenDecimalsTooLow() public {
        MockERC20 accountingToken2 =
            new MockERC20("Accounting Token 2", "AT2", Constants.MIN_ACCOUNTING_TOKEN_DECIMALS - 1);

        vm.expectRevert(IMachine.InvalidDecimals.selector);
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(IMachine.initialize, (_getMachineInitParams(address(accountingToken2))))
        );
    }

    function test_cannotDeployMachineWithAccoutingTokenDecimalsTooHigh() public {
        MockERC20 accountingToken2 =
            new MockERC20("Accounting Token 2", "AT2", Constants.MAX_ACCOUNTING_TOKEN_DECIMALS + 1);

        vm.expectRevert(IMachine.InvalidDecimals.selector);
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(IMachine.initialize, (_getMachineInitParams(address(accountingToken2))))
        );
    }

    function test_cannotDeployMachineWithNonPriceableAccountingToken() public {
        MockERC20 accountingToken2 = new MockERC20("Accounting Token 2", "AT2", 18);
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        new BeaconProxy(
            address(machineBeacon),
            abi.encodeCall(IMachine.initialize, (_getMachineInitParams(address(accountingToken2))))
        );
    }

    function _getMachineInitParams(address accountingToken) internal view returns (IMachine.MachineInitParams memory) {
        return IMachine.MachineInitParams({
            accountingToken: accountingToken,
            initialMechanic: mechanic,
            initialSecurityCouncil: securityCouncil,
            initialAuthority: address(accessManager),
            initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
            hubCaliberAccountingTokenPosID: accountingTokenPosId,
            hubCaliberPosStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
            hubCaliberAllowedInstrRoot: bytes32(""),
            hubCaliberTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
            hubCaliberMaxMgmtLossBps: DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS,
            hubCaliberMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS
        });
    }
}
