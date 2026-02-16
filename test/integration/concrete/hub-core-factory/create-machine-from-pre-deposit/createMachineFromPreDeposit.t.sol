// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Errors} from "src/libraries/Errors.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberFactory} from "src/interfaces/ICaliberFactory.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IHubCoreFactory} from "src/interfaces/IHubCoreFactory.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Machine} from "src/machine/Machine.sol";
import {MockFeeManager} from "test/mocks/MockFeeManager.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";
import {Roles} from "src/libraries/Roles.sol";

import {HubCoreFactory_Integration_Concrete_Test} from "../HubCoreFactory.t.sol";

contract CreateMachineFromPreDeposit_Integration_Concrete_Test is HubCoreFactory_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubCoreFactory.createMachineFromPreDeposit(mParams, cParams, mgParams, address(0), bytes32(0), false);
    }

    function test_RevertWhen_InvalidPreDepositVault() public {
        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.NotPreDepositVault.selector);
        hubCoreFactory.createMachineFromPreDeposit(mParams, cParams, mgParams, address(0), bytes32(0), false);
    }

    function test_RevertWhen_ZeroSalt() public {
        vm.prank(dao);
        preDepositVault = _deployDepositVault();

        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.ZeroSalt.selector);
        hubCoreFactory.createMachineFromPreDeposit(
            mParams, cParams, mgParams, address(preDepositVault), bytes32(0), false
        );
    }

    function test_RevertWhen_SaltAlreadyUsed() public {
        vm.prank(dao);
        preDepositVault = _deployDepositVault();

        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.TargetAlreadyExists.selector);
        hubCoreFactory.createMachineFromPreDeposit(
            mParams, cParams, mgParams, address(preDepositVault), TEST_DEPLOYMENT_SALT, false
        );
    }

    function test_RevertGiven_CaliberCreate3ProxyDeploymentFailed() public {
        // deploy a proxy to occupy the proxy CREATE2 address
        bytes memory _proxyInitcode = hex"67363d3d37363d34f03d5260086018f3";
        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);
        bytes32 nSalt = keccak256(abi.encode(keccak256("makina.salt.Caliber"), salt));
        address proxy;
        vm.prank(address(hubCoreFactory));
        assembly {
            proxy := create2(0, add(_proxyInitcode, 0x20), mload(_proxyInitcode), nSalt)
        }

        vm.prank(dao);
        preDepositVault = _deployDepositVault();

        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.Create3ProxyDeploymentFailed.selector);
        hubCoreFactory.createMachineFromPreDeposit(mParams, cParams, mgParams, address(preDepositVault), salt, false);
    }

    function test_RevertWhen_AMSetupAndOtherAuthority() public {
        AccessManagerUpgradeable accessManager2 = _deployAccessManager(address(this), address(this));

        vm.prank(dao);
        preDepositVault = _deployDepositVault();

        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);

        vm.expectRevert(Errors.NotFactoryAuthority.selector);
        vm.prank(dao);
        machine = Machine(
            hubCoreFactory.createMachineFromPreDeposit(
                IMachine.MachineInitParams({
                    initialDepositor: machineDepositor,
                    initialRedeemer: machineRedeemer,
                    initialFeeManager: address(0),
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialMaxFixedFeeAccrualRate: DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE,
                    initialMaxPerfFeeAccrualRate: DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE,
                    initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialMaxSharePriceChangeRate: DEFAULT_MACHINE_MAX_SHARE_PRICE_CHANGE_RATE
                }),
                ICaliber.CaliberInitParams({
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: initialAllowedInstrRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION,
                    initialBaseTokens: new address[](0)
                }),
                IMakinaGovernable.MakinaGovernableInitParams({
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialRiskManager: riskManager,
                    initialRiskManagerTimelock: riskManagerTimelock,
                    initialAuthority: address(accessManager2),
                    initialRestrictedAccountingMode: false
                }),
                address(preDepositVault),
                salt,
                true
            )
        );
    }

    function test_CreateMachineFromPreDeposit_AMSetup() public {
        MockFeeManager feeManager2 =
            new MockFeeManager(dao, DEFAULT_FEE_MANAGER_FIXED_FEE_RATE, DEFAULT_FEE_MANAGER_PERF_FEE_RATE);

        initialAllowedInstrRoot = bytes32("0x12345");

        vm.prank(dao);
        preDepositVault = _deployDepositVault();

        uint256 preDepositAmount = 1e18;
        deal(address(baseToken), address(this), preDepositAmount);
        baseToken.approve(address(preDepositVault), preDepositAmount);
        uint256 shares = preDepositVault.deposit(preDepositAmount, address(this), 0, 0);

        address[] memory initialBaseTokens = new address[](1);
        initialBaseTokens[0] = address(baseToken);

        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);

        vm.expectEmit(false, false, false, false, address(hubCoreFactory));
        emit ICaliberFactory.CaliberCreated(address(0), address(0));

        vm.expectEmit(false, false, false, false, address(preDepositVault));
        emit IPreDepositVault.MigrateToMachine(address(0));

        vm.expectEmit(false, false, false, false, address(hubCoreFactory));
        emit IHubCoreFactory.MachineCreated(address(0), address(0));

        vm.prank(dao);
        machine = Machine(
            hubCoreFactory.createMachineFromPreDeposit(
                IMachine.MachineInitParams({
                    initialDepositor: machineDepositor,
                    initialRedeemer: machineRedeemer,
                    initialFeeManager: address(feeManager2),
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialMaxFixedFeeAccrualRate: DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE,
                    initialMaxPerfFeeAccrualRate: DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE,
                    initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialMaxSharePriceChangeRate: DEFAULT_MACHINE_MAX_SHARE_PRICE_CHANGE_RATE
                }),
                ICaliber.CaliberInitParams({
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: initialAllowedInstrRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION,
                    initialBaseTokens: initialBaseTokens
                }),
                IMakinaGovernable.MakinaGovernableInitParams({
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialRiskManager: riskManager,
                    initialRiskManagerTimelock: riskManagerTimelock,
                    initialAuthority: address(accessManager),
                    initialRestrictedAccountingMode: false
                }),
                address(preDepositVault),
                salt,
                true
            )
        );

        assertTrue(preDepositVault.migrated());

        Caliber caliber = Caliber(machine.hubCaliber());

        assertTrue(hubCoreFactory.isMachine(address(machine)));
        assertTrue(hubCoreFactory.isCaliber(address(caliber)));

        assertEq(machine.registry(), address(hubCoreRegistry));
        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.depositor(), machineDepositor);
        assertEq(machine.redeemer(), machineRedeemer);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.shareLimit(), DEFAULT_MACHINE_SHARE_LIMIT);

        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.riskManager(), riskManager);
        assertEq(machine.riskManagerTimelock(), riskManagerTimelock);
        assertEq(machine.authority(), address(accessManager));
        assertFalse(machine.restrictedAccountingMode());

        assertTrue(machine.isIdleToken(address(accountingToken)));
        assertEq(machine.getSpokeCalibersLength(), 0);

        IMachineShare shareToken = IMachineShare(machine.shareToken());
        assertEq(address(shareToken), preDepositVault.shareToken());
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
        assertEq(shareToken.totalSupply(), shares);

        assertEq(caliber.hubMachineEndpoint(), address(machine));
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
        assertEq(caliber.allowedInstrRoot(), initialAllowedInstrRoot);
        assertEq(caliber.timelockDuration(), DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK);
        assertEq(caliber.maxPositionIncreaseLossBps(), DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS);
        assertEq(caliber.maxPositionDecreaseLossBps(), DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS);
        assertEq(caliber.maxSwapLossBps(), DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS);
        assertEq(caliber.authority(), address(accessManager));

        assertEq(caliber.getPositionsLength(), 0);
        assertEq(caliber.getBaseTokensLength(), 2);
        assertEq(caliber.getBaseToken(0), address(accountingToken));
        assertEq(caliber.getBaseToken(1), address(baseToken));

        assertTrue(machine.isIdleToken(address(baseToken)));
        assertEq(baseToken.balanceOf(address(preDepositVault)), 0);
        assertEq(baseToken.balanceOf(address(machine)), preDepositAmount);

        // Machine function roles should be set according to HubCoreFactory setup
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IBridgeController.createBridgeAdapter.selector),
            Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMachine.setSpokeCaliber.selector),
            Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMachine.setSpokeBridgeAdapter.selector),
            Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMachine.setDepositor.selector),
            Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMachine.setRedeemer.selector),
            Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMachine.setFeeManager.selector),
            Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.setMechanic.selector),
            Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.setSecurityCouncil.selector),
            Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.setRiskManager.selector),
            Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.setRiskManagerTimelock.selector),
            Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(
                address(machine), IMakinaGovernable.setRestrictedAccountingMode.selector
            ),
            Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.addAccountingAgent.selector),
            Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.removeAccountingAgent.selector),
            Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );

        // Caliber function roles should be set according to HubCoreFactory setup
        assertEq(
            accessManager.getTargetFunctionRole(address(caliber), ICaliber.addInstrRootGuardian.selector),
            Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(caliber), ICaliber.removeInstrRootGuardian.selector),
            Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE
        );

        // Fee Manager function role 3 should be set for function selectors returned by getRestrictedFeeConfigSelectors
        assertEq(
            accessManager.getTargetFunctionRole(address(feeManager2), MockFeeManager.setFixedFeeRate.selector),
            Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(feeManager2), MockFeeManager.setPerfFeeRate.selector),
            Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(feeManager2), MockFeeManager.setDistributionRate.selector),
            Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );
    }

    function test_CreateMachineFromPreDeposit_WithoutAMSetup() public {
        MockFeeManager feeManager2 =
            new MockFeeManager(dao, DEFAULT_FEE_MANAGER_FIXED_FEE_RATE, DEFAULT_FEE_MANAGER_PERF_FEE_RATE);

        initialAllowedInstrRoot = bytes32("0x12345");

        address[] memory initialBaseTokens = new address[](1);
        initialBaseTokens[0] = address(baseToken);

        vm.prank(dao);
        preDepositVault = _deployDepositVault();

        uint256 preDepositAmount = 1e18;
        deal(address(baseToken), address(this), preDepositAmount);
        baseToken.approve(address(preDepositVault), preDepositAmount);
        uint256 shares = preDepositVault.deposit(preDepositAmount, address(this), 0, 0);

        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);

        vm.expectEmit(false, false, false, false, address(hubCoreFactory));
        emit ICaliberFactory.CaliberCreated(address(0), address(0));

        vm.expectEmit(false, false, false, false, address(preDepositVault));
        emit IPreDepositVault.MigrateToMachine(address(0));

        vm.expectEmit(false, false, false, false, address(hubCoreFactory));
        emit IHubCoreFactory.MachineCreated(address(0), address(0));

        vm.prank(dao);
        machine = Machine(
            hubCoreFactory.createMachineFromPreDeposit(
                IMachine.MachineInitParams({
                    initialDepositor: machineDepositor,
                    initialRedeemer: machineRedeemer,
                    initialFeeManager: address(feeManager2),
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialMaxFixedFeeAccrualRate: DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE,
                    initialMaxPerfFeeAccrualRate: DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE,
                    initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialMaxSharePriceChangeRate: DEFAULT_MACHINE_MAX_SHARE_PRICE_CHANGE_RATE
                }),
                ICaliber.CaliberInitParams({
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: initialAllowedInstrRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION,
                    initialBaseTokens: initialBaseTokens
                }),
                IMakinaGovernable.MakinaGovernableInitParams({
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialRiskManager: riskManager,
                    initialRiskManagerTimelock: riskManagerTimelock,
                    initialAuthority: address(accessManager),
                    initialRestrictedAccountingMode: false
                }),
                address(preDepositVault),
                salt,
                false
            )
        );

        assertTrue(preDepositVault.migrated());

        Caliber caliber = Caliber(machine.hubCaliber());

        assertTrue(hubCoreFactory.isMachine(address(machine)));
        assertTrue(hubCoreFactory.isCaliber(address(caliber)));

        assertEq(machine.registry(), address(hubCoreRegistry));
        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.depositor(), machineDepositor);
        assertEq(machine.redeemer(), machineRedeemer);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.shareLimit(), DEFAULT_MACHINE_SHARE_LIMIT);

        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.riskManager(), riskManager);
        assertEq(machine.riskManagerTimelock(), riskManagerTimelock);
        assertEq(machine.authority(), address(accessManager));
        assertFalse(machine.restrictedAccountingMode());

        assertTrue(machine.isIdleToken(address(accountingToken)));
        assertEq(machine.getSpokeCalibersLength(), 0);

        IMachineShare shareToken = IMachineShare(machine.shareToken());
        assertEq(address(shareToken), preDepositVault.shareToken());
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
        assertEq(shareToken.totalSupply(), shares);

        assertEq(caliber.hubMachineEndpoint(), address(machine));
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
        assertEq(caliber.allowedInstrRoot(), initialAllowedInstrRoot);
        assertEq(caliber.timelockDuration(), DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK);
        assertEq(caliber.maxPositionIncreaseLossBps(), DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS);
        assertEq(caliber.maxPositionDecreaseLossBps(), DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS);
        assertEq(caliber.maxSwapLossBps(), DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS);
        assertEq(caliber.authority(), address(accessManager));

        assertEq(caliber.getPositionsLength(), 0);
        assertEq(caliber.getBaseTokensLength(), 2);
        assertEq(caliber.getBaseToken(0), address(accountingToken));
        assertEq(caliber.getBaseToken(1), address(baseToken));

        assertTrue(machine.isIdleToken(address(baseToken)));
        assertEq(baseToken.balanceOf(address(preDepositVault)), 0);
        assertEq(baseToken.balanceOf(address(machine)), preDepositAmount);

        // Machine function roles should be set to 0 by default
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IBridgeController.createBridgeAdapter.selector), 0
        );
        assertEq(accessManager.getTargetFunctionRole(address(machine), IMachine.setSpokeCaliber.selector), 0);
        assertEq(accessManager.getTargetFunctionRole(address(machine), IMachine.setSpokeBridgeAdapter.selector), 0);
        assertEq(accessManager.getTargetFunctionRole(address(machine), IMachine.setDepositor.selector), 0);
        assertEq(accessManager.getTargetFunctionRole(address(machine), IMachine.setRedeemer.selector), 0);
        assertEq(accessManager.getTargetFunctionRole(address(machine), IMachine.setFeeManager.selector), 0);
        assertEq(accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.setMechanic.selector), 0);
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.setSecurityCouncil.selector), 0
        );
        assertEq(accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.setRiskManager.selector), 0);
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.setRiskManagerTimelock.selector), 0
        );
        assertEq(
            accessManager.getTargetFunctionRole(
                address(machine), IMakinaGovernable.setRestrictedAccountingMode.selector
            ),
            0
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.addAccountingAgent.selector), 0
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(machine), IMakinaGovernable.removeAccountingAgent.selector), 0
        );

        // Caliber function roles should be set to 0 by default
        assertEq(accessManager.getTargetFunctionRole(address(caliber), ICaliber.addInstrRootGuardian.selector), 0);
        assertEq(accessManager.getTargetFunctionRole(address(caliber), ICaliber.removeInstrRootGuardian.selector), 0);

        // FeeManager function roles should be set to 0 by default
        assertEq(accessManager.getTargetFunctionRole(address(feeManager2), MockFeeManager.setFixedFeeRate.selector), 0);
        assertEq(accessManager.getTargetFunctionRole(address(feeManager2), MockFeeManager.setPerfFeeRate.selector), 0);
        assertEq(
            accessManager.getTargetFunctionRole(address(feeManager2), MockFeeManager.setDistributionRate.selector), 0
        );
    }

    function _deployDepositVault() internal returns (PreDepositVault) {
        return PreDepositVault(
            hubCoreFactory.createPreDepositVault(
                IPreDepositVault.PreDepositVaultInitParams({
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialWhitelistMode: false,
                    initialRiskManager: address(0),
                    initialAuthority: address(accessManager)
                }),
                address(baseToken),
                address(accountingToken),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL,
                true
            )
        );
    }
}
