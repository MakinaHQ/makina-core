// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {MockPool} from "test/mocks/MockPool.sol";

import {Base_Test} from "test/BaseTest.sol";

contract Machine_Unit_Concrete_Test is Base_Test {
    MockPriceFeed internal aPriceFeed1;

    function _setUp() public virtual override {
        aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine,) = _deployMachine(address(accountingToken), accountingTokenPosId, bytes32(0));
    }

    function test_machine_getters() public view {
        assertEq(machine.registry(), address(hubRegistry));
        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.recoveryMode(), false);
        assertEq(machine.lastReportedTotalAum(), 0);
        assertEq(machine.lastReportedTotalAumTime(), 0);
        assertEq(machine.getCalibersLength(), 1);
        assertEq(machine.getSupportedChainId(0), block.chainid);
        assertNotEq(machine.getMailbox(block.chainid), address(0));
    }

    function test_cannotSetMechanicWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setMechanic(address(0x0));
    }

    function test_setMechanic() public {
        address newMechanic = makeAddr("NewMechanic");
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.MechanicChanged(mechanic, newMechanic);
        vm.prank(dao);
        machine.setMechanic(newMechanic);
        assertEq(machine.mechanic(), newMechanic);
    }

    function test_cannotSetSecurityCouncilWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setSecurityCouncil(address(0x0));
    }

    function test_setSecurityCouncil() public {
        address newSecurityCouncil = makeAddr("NewSecurityCouncil");
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.SecurityCouncilChanged(securityCouncil, newSecurityCouncil);
        vm.prank(dao);
        machine.setSecurityCouncil(newSecurityCouncil);
        assertEq(machine.securityCouncil(), newSecurityCouncil);
    }

    function test_cannotSetCaliberStaleThresholdWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setCaliberStaleThreshold(2 hours);
    }

    function test_setCaliberStaleThreshold() public {
        uint256 newThreshold = 2 hours;
        emit IMachine.CaliberStaleThresholdChanged(DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD, newThreshold);
        vm.prank(dao);
        machine.setCaliberStaleThreshold(newThreshold);
        assertEq(machine.caliberStaleThreshold(), newThreshold);
    }

    function test_cannotSetRecoveryModeWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setRecoveryMode(true);
    }

    function test_setRecoveryMode() public {
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.RecoveryModeChanged(true);
        vm.prank(dao);
        machine.setRecoveryMode(true);
        assertTrue(machine.recoveryMode());
    }
}
