// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IHubDualMailbox} from "src/interfaces/IHubDualMailbox.sol";
import {Machine} from "src/machine/Machine.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {Base_Test} from "test/BaseTest.sol";

contract MachineFactory_Integration_Concrete_Test is Base_Test {
    event MachineDeployed(address indexed machine);

    MockPriceFeed private aPriceFeed1;

    bytes32 private initialAllowedInstrRoot;

    function _setUp() public override {
        aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
    }

    function test_getters() public view {
        assertEq(machineFactory.registry(), address(hubRegistry));
        assertEq(machineFactory.isMachine(address(0)), false);
    }

    function test_cannotDeployMachineWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machineFactory.deployMachine(address(0), address(0), address(0), address(0), 0, 0, 0, bytes32(0), 0, 0, 0);
    }

    function test_deployMachine() public {
        initialAllowedInstrRoot = bytes32("0x12345");

        // vm.expectEmit(false, false, false, false, address(machineFactory));
        // emit MachineDeployed(address(0));
        vm.prank(dao);
        machine = Machine(
            machineFactory.deployMachine(
                address(accountingToken),
                mechanic,
                securityCouncil,
                address(accessManager),
                DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                accountingTokenPosId,
                DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                initialAllowedInstrRoot,
                DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS,
                DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS
            )
        );
        assertEq(machineFactory.isMachine(address(machine)), true);

        assertEq(machine.registry(), address(hubRegistry));
        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.authority(), address(accessManager));
        assertTrue(machine.isIdleToken(address(accountingToken)));

        assertEq(machine.getCalibersLength(), 1);

        address hubDualMailbox = machine.getMailbox(block.chainid);
        address caliber = IHubDualMailbox(hubDualMailbox).caliber();
        assertEq(IHubDualMailbox(hubDualMailbox).machine(), address(machine));
        assertEq(ICaliber(caliber).mailbox(), hubDualMailbox);
    }
}
