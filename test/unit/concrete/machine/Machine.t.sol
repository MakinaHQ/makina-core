// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IMachine} from "src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {DecimalsUtils} from "src/libraries/DecimalsUtils.sol";
import {Errors} from "src/libraries/Errors.sol";

import {MakinaGovernable_Unit_Concrete_Test} from "../makina-governable/MakinaGovernable.t.sol";
import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

abstract contract Machine_Unit_Concrete_Test is Unit_Concrete_Hub_Test {
    address public spokeCaliberMailboxAddr;
    address public spokeBridgeAdapterAddr;

    function setUp() public virtual override {
        Unit_Concrete_Hub_Test.setUp();

        vm.prank(dao);
        chainRegistry.setChainIds(SPOKE_CHAIN_ID, WORMHOLE_SPOKE_CHAIN_ID);

        spokeCaliberMailboxAddr = makeAddr("spokeCaliberMailbox");
        spokeBridgeAdapterAddr = makeAddr("spokeBridgeAdapter");
    }
}

contract MakinaGovernable_Machine_Unit_Concrete_Test is MakinaGovernable_Unit_Concrete_Test, Unit_Concrete_Hub_Test {
    function setUp() public override(MakinaGovernable_Unit_Concrete_Test, Unit_Concrete_Hub_Test) {
        Unit_Concrete_Hub_Test.setUp();
        governable = IMakinaGovernable(address(machine));
    }
}

contract Getters_Setters_Machine_Unit_Concrete_Test is Unit_Concrete_Hub_Test {
    function test_Getters() public view {
        assertEq(machine.depositor(), machineDepositor);
        assertEq(machine.redeemer(), machineRedeemer);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.hubCaliber(), address(caliber));
        assertEq(machine.feeManager(), address(feeManager));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.maxFeeAccrualRate(), DEFAULT_MACHINE_MAX_FEE_ACCRUAL_RATE);
        assertEq(machine.feeMintCooldown(), DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        assertEq(machine.maxMint(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(machine.lastTotalAum(), 0);
        assertEq(machine.lastGlobalAccountingTime(), 0);

        assertTrue(machine.isIdleToken(address(accountingToken)));
        assertEq(machine.getSpokeCalibersLength(), 0);
    }

    function test_ConvertToShares() public view {
        // should hold when no yield occurred
        assertEq(machine.convertToShares(10 ** accountingToken.decimals()), 10 ** DecimalsUtils.SHARE_TOKEN_DECIMALS);
    }

    function test_SetDepositor_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setDepositor(address(0));
    }

    function test_SetDepositor() public {
        address newDepositor = makeAddr("NewDepositor");
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.DepositorChanged(machineDepositor, newDepositor);
        vm.prank(dao);
        machine.setDepositor(newDepositor);
        assertEq(machine.depositor(), newDepositor);
    }

    function test_SetRedeemer_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setRedeemer(address(0));
    }

    function test_SetRedeemer() public {
        address newRedeemer = makeAddr("NewRedeemer");
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.RedeemerChanged(machineRedeemer, newRedeemer);
        vm.prank(dao);
        machine.setRedeemer(newRedeemer);
        assertEq(machine.redeemer(), newRedeemer);
    }

    function test_SetFeeManager_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setFeeManager(address(0));
    }

    function test_SetFeeManager() public {
        address newFeeManager = makeAddr("NewFeeManager");
        vm.expectEmit(true, true, false, false, address(machine));
        emit IMachine.FeeManagerChanged(address(feeManager), newFeeManager);
        vm.prank(dao);
        machine.setFeeManager(newFeeManager);
        assertEq(machine.feeManager(), newFeeManager);
    }

    function test_SetCaliberStaleThreshold_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.setCaliberStaleThreshold(2 hours);
    }

    function test_SetCaliberStaleThreshold() public {
        uint256 newThreshold = 2 hours;
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.CaliberStaleThresholdChanged(DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD, newThreshold);
        vm.prank(riskManagerTimelock);
        machine.setCaliberStaleThreshold(newThreshold);
        assertEq(machine.caliberStaleThreshold(), newThreshold);
    }

    function test_SetMaxFeeAccrualRate_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setMaxFeeAccrualRate(1e18);
    }

    function test_SetMaxFeeAccrualRate() public {
        uint256 newMaxFeeAccrualRate = 1e18;
        vm.expectEmit(true, true, false, false, address(machine));
        emit IMachine.MaxFeeAccrualRateChanged(DEFAULT_MACHINE_MAX_FEE_ACCRUAL_RATE, newMaxFeeAccrualRate);
        vm.prank(dao);
        machine.setMaxFeeAccrualRate(newMaxFeeAccrualRate);
        assertEq(machine.maxFeeAccrualRate(), newMaxFeeAccrualRate);
    }

    function test_SetFeeMintCooldown_RevertWhenCallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setFeeMintCooldown(1 hours);
    }

    function test_SetFeeMintCooldown() public {
        uint256 newFeeMintCooldown = 1 hours;
        vm.expectEmit(true, true, false, false, address(machine));
        emit IMachine.FeeMintCooldownChanged(DEFAULT_MACHINE_FEE_MINT_COOLDOWN, newFeeMintCooldown);
        vm.prank(dao);
        machine.setFeeMintCooldown(newFeeMintCooldown);
        assertEq(machine.feeMintCooldown(), newFeeMintCooldown);
    }

    function test_SetShareLimit_RevertWhen_CallerNotRM() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.setShareLimit(1e18);
    }

    function test_SetShareLimit() public {
        uint256 newShareLimit = 1e18;
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.ShareLimitChanged(DEFAULT_MACHINE_SHARE_LIMIT, newShareLimit);
        vm.prank(riskManager);
        machine.setShareLimit(newShareLimit);
        assertEq(machine.shareLimit(), newShareLimit);
    }
}
