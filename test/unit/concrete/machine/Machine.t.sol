// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
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
import {Constants} from "src/libraries/Constants.sol";

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
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.maxMint(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(machine.lastTotalAum(), 0);
        assertEq(machine.lastGlobalAccountingTime(), 0);
        assertEq(machine.getCalibersLength(), 1);
        assertEq(machine.getSupportedChainId(0), block.chainid);
        assertNotEq(machine.getMailbox(block.chainid), address(0));
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_convertToShares() public {
        // should hold when no yield occurred
        assertEq(machine.convertToShares(10 ** accountingToken.decimals()), 10 ** Constants.SHARE_TOKEN_DECIMALS);
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
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.CaliberStaleThresholdChanged(DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD, newThreshold);
        vm.prank(dao);
        machine.setCaliberStaleThreshold(newThreshold);
        assertEq(machine.caliberStaleThreshold(), newThreshold);
    }

    function test_cannotSetShareLimitWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setShareLimit(1e18);
    }

    function test_setShareLimit() public {
        uint256 newShareLimit = 1e18;
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.ShareLimitChanged(DEFAULT_MACHINE_SHARE_LIMIT, newShareLimit);
        vm.prank(dao);
        machine.setShareLimit(newShareLimit);
        assertEq(machine.shareLimit(), newShareLimit);
    }

    function test_cannotSetDepositorOnlyModeWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setDepositorOnlyMode(true);
    }

    function test_setDepositorOnlyMode() public {
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.DepositorOnlyModeChanged(true);
        vm.prank(dao);
        machine.setDepositorOnlyMode(true);
        assertTrue(machine.depositorOnlyMode());
    }

    function test_cannotSetRecoveryModeWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setRecoveryMode(true);
    }

    function test_setRecoveryMode() public {
        vm.expectEmit(true, false, false, true, address(machine));
        emit IMachine.RecoveryModeChanged(true);
        vm.prank(dao);
        machine.setRecoveryMode(true);
        assertTrue(machine.recoveryMode());
    }
}
