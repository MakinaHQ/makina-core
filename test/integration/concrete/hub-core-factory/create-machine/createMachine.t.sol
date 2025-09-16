// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Errors} from "src/libraries/Errors.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberFactory} from "src/interfaces/ICaliberFactory.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IHubCoreFactory} from "src/interfaces/IHubCoreFactory.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {Machine} from "src/machine/Machine.sol";

import {HubCoreFactory_Integration_Concrete_Test} from "../HubCoreFactory.t.sol";

contract CreateMachine_Integration_Concrete_Test is HubCoreFactory_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubCoreFactory.createMachine(mParams, cParams, mgParams, address(0), "", "", bytes32(0));
    }

    function test_RevertWhen_ZeroSalt() public {
        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.ZeroSalt.selector);
        hubCoreFactory.createMachine(mParams, cParams, mgParams, address(0), "", "", bytes32(0));
    }

    function test_RevertWhen_SaltAlreadyUsed() public {
        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.TargetAlreadyExists.selector);
        hubCoreFactory.createMachine(mParams, cParams, mgParams, address(0), "", "", TEST_DEPLOYMENT_SALT);
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

        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.Create3ProxyDeploymentFailed.selector);
        hubCoreFactory.createMachine(mParams, cParams, mgParams, address(0), "", "", salt);
    }

    function test_RevertGiven_CaliberCreate3ContractDeploymentFailed() public {
        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);

        IMachine.MachineInitParams memory mParams;
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.Create3ContractDeploymentFailed.selector);
        hubCoreFactory.createMachine(mParams, cParams, mgParams, address(0), "", "", salt);
    }

    function test_CreateMachine() public {
        initialAllowedInstrRoot = bytes32("0x12345");

        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);

        vm.expectEmit(false, false, false, false, address(hubCoreFactory));
        emit ICaliberFactory.CaliberCreated(address(0), address(0));

        vm.expectEmit(false, false, false, false, address(hubCoreFactory));
        emit IHubCoreFactory.MachineCreated(address(0), address(0));

        vm.prank(dao);
        machine = Machine(
            hubCoreFactory.createMachine(
                IMachine.MachineInitParams({
                    initialDepositor: machineDepositor,
                    initialRedeemer: machineRedeemer,
                    initialFeeManager: address(feeManager),
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialMaxFixedFeeAccrualRate: DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE,
                    initialMaxPerfFeeAccrualRate: DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE,
                    initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT
                }),
                ICaliber.CaliberInitParams({
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: initialAllowedInstrRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION
                }),
                IMakinaGovernable.MakinaGovernableInitParams({
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialRiskManager: riskManager,
                    initialRiskManagerTimelock: riskManagerTimelock,
                    initialAuthority: address(accessManager)
                }),
                address(accountingToken),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL,
                salt
            )
        );
        address caliber = machine.hubCaliber();

        assertTrue(hubCoreFactory.isMachine(address(machine)));
        assertTrue(hubCoreFactory.isCaliber(address(caliber)));

        assertEq(ICaliber(caliber).hubMachineEndpoint(), address(machine));

        assertEq(machine.registry(), address(hubCoreRegistry));
        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.depositor(), machineDepositor);
        assertEq(machine.redeemer(), machineRedeemer);
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.shareLimit(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(machine.authority(), address(accessManager));
        assertTrue(machine.isIdleToken(address(accountingToken)));
        assertEq(machine.getSpokeCalibersLength(), 0);

        IMachineShare shareToken = IMachineShare(machine.shareToken());
        assertEq(shareToken.minter(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
    }
}
