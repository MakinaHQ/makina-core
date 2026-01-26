// SPDX-License-Identifier: BUSL-1.1
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
        assertEq(machine.maxFixedFeeAccrualRate(), DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE);
        assertEq(machine.maxPerfFeeAccrualRate(), DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE);
        assertEq(machine.feeMintCooldown(), DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        assertEq(machine.shareLimit(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(machine.maxSharePriceChangeRate(), DEFAULT_MACHINE_MAX_SHARE_PRICE_CHANGE_RATE);

        assertEq(machine.maxMint(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(machine.lastTotalAum(), 0);
        assertEq(machine.lastGlobalAccountingTime(), 1);

        assertTrue(machine.isIdleToken(address(accountingToken)));
        assertEq(machine.getIdleTokensLength(), 1);
        assertEq(machine.getIdleToken(0), address(accountingToken));

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

    function test_SetMaxFixedFeeAccrualRate_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.setMaxFixedFeeAccrualRate(1e18);
    }

    function test_SetMaxFixedFeeAccrualRate() public {
        uint256 newMaxAccrualRate = 1e18;
        vm.expectEmit(true, true, false, false, address(machine));
        emit IMachine.MaxFixedFeeAccrualRateChanged(DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE, newMaxAccrualRate);
        vm.prank(riskManagerTimelock);
        machine.setMaxFixedFeeAccrualRate(newMaxAccrualRate);
        assertEq(machine.maxFixedFeeAccrualRate(), newMaxAccrualRate);
    }

    function test_SetMaxPerfFeeAccrualRate_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.setMaxPerfFeeAccrualRate(1e18);
    }

    function test_SetMaxPerfFeeAccrualRate() public {
        uint256 newMaxAccrualRate = 1e18;
        vm.expectEmit(true, true, false, false, address(machine));
        emit IMachine.MaxPerfFeeAccrualRateChanged(DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE, newMaxAccrualRate);
        vm.prank(riskManagerTimelock);
        machine.setMaxPerfFeeAccrualRate(newMaxAccrualRate);
        assertEq(machine.maxPerfFeeAccrualRate(), newMaxAccrualRate);
    }

    function test_SetFeeMintCooldown_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.setFeeMintCooldown(1 hours);
    }

    function test_SetFeeMintCooldown() public {
        uint256 newFeeMintCooldown = 1 hours;
        vm.expectEmit(true, true, false, false, address(machine));
        emit IMachine.FeeMintCooldownChanged(DEFAULT_MACHINE_FEE_MINT_COOLDOWN, newFeeMintCooldown);
        vm.prank(riskManagerTimelock);
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

    function test_SetMaxSharePriceChangeRate_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.setMaxSharePriceChangeRate(1e18);
    }

    function test_SetMaxSharePriceChangeRate() public {
        uint256 newMaxSharePriceChangeRate = 1e18;
        vm.expectEmit(true, true, false, false, address(machine));
        emit IMachine.MaxSharePriceChangeRateChanged(
            DEFAULT_MACHINE_MAX_SHARE_PRICE_CHANGE_RATE, newMaxSharePriceChangeRate
        );
        vm.prank(riskManagerTimelock);
        machine.setMaxSharePriceChangeRate(newMaxSharePriceChangeRate);
        assertEq(machine.maxSharePriceChangeRate(), newMaxSharePriceChangeRate);
    }
}
