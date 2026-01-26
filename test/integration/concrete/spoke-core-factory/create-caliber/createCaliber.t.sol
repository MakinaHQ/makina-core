// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Errors} from "src/libraries/Errors.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberFactory} from "src/interfaces/ICaliberFactory.sol";
import {ISpokeCoreFactory} from "src/interfaces/ISpokeCoreFactory.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {CaliberMailbox} from "src/caliber/CaliberMailbox.sol";

import {SpokeCoreFactory_Integration_Concrete_Test} from "../SpokeCoreFactory.t.sol";

contract CreateCaliber_Integration_Concrete_Test is SpokeCoreFactory_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeCoreFactory.createCaliber(cParams, mgParams, address(0), address(0), bytes32(0));
    }

    function test_RevertWhen_ZeroSalt() public {
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.ZeroSalt.selector);
        spokeCoreFactory.createCaliber(cParams, mgParams, address(0), address(0), bytes32(0));
    }

    function test_RevertWhen_SaltAlreadyUsed() public {
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.TargetAlreadyExists.selector);
        spokeCoreFactory.createCaliber(cParams, mgParams, address(0), address(0), TEST_DEPLOYMENT_SALT);
    }

    function test_RevertGiven_CaliberCreate3ProxyDeploymentFailed() public {
        // deploy a proxy to occupy the proxy CREATE2 address
        bytes memory _proxyInitcode = hex"67363d3d37363d34f03d5260086018f3";
        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);
        bytes32 nSalt = keccak256(abi.encode(keccak256("makina.salt.Caliber"), salt));
        address proxy;
        vm.prank(address(spokeCoreFactory));
        assembly {
            proxy := create2(0, add(_proxyInitcode, 0x20), mload(_proxyInitcode), nSalt)
        }

        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.Create3ProxyDeploymentFailed.selector);
        spokeCoreFactory.createCaliber(cParams, mgParams, address(0), address(0), salt);
    }

    function test_RevertGiven_CaliberCreate3ContractDeploymentFailed() public {
        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);

        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;

        vm.prank(dao);
        vm.expectRevert(Errors.Create3ContractDeploymentFailed.selector);
        spokeCoreFactory.createCaliber(cParams, mgParams, address(0), address(0), salt);
    }

    function test_CreateCaliber() public {
        address _hubMachine = makeAddr("hubMachine");
        bytes32 initialAllowedInstrRoot = bytes32("0x12345");

        bytes32 salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);

        vm.expectEmit(false, false, false, false, address(spokeCoreFactory));
        emit ICaliberFactory.CaliberCreated(address(0), address(0));

        vm.expectEmit(false, false, true, false, address(spokeCoreFactory));
        emit ISpokeCoreFactory.CaliberMailboxCreated(address(0), address(0), _hubMachine);

        vm.prank(dao);
        caliber = Caliber(
            spokeCoreFactory.createCaliber(
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
                    initialAuthority: address(accessManager),
                    initialRestrictedAccountingMode: false
                }),
                address(accountingToken),
                _hubMachine,
                salt
            )
        );
        assertTrue(spokeCoreFactory.isCaliber(address(caliber)));
        assertTrue(spokeCoreFactory.isCaliberMailbox(caliber.hubMachineEndpoint()));

        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
        assertEq(caliber.allowedInstrRoot(), initialAllowedInstrRoot);
        assertEq(caliber.timelockDuration(), DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK);
        assertEq(caliber.maxPositionIncreaseLossBps(), DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS);
        assertEq(caliber.maxPositionDecreaseLossBps(), DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS);
        assertEq(caliber.maxSwapLossBps(), DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS);

        caliberMailbox = CaliberMailbox(caliber.hubMachineEndpoint());
        assertEq(caliberMailbox.caliber(), address(caliber));

        assertEq(caliberMailbox.mechanic(), mechanic);
        assertEq(caliberMailbox.securityCouncil(), securityCouncil);
        assertEq(caliberMailbox.riskManager(), riskManager);
        assertEq(caliberMailbox.riskManagerTimelock(), riskManagerTimelock);
        assertEq(caliberMailbox.authority(), address(accessManager));
        assertEq(caliber.authority(), address(accessManager));
        assertFalse(caliberMailbox.restrictedAccountingMode());

        assertEq(caliber.getPositionsLength(), 0);
        assertEq(caliber.getBaseTokensLength(), 1);
        assertEq(caliber.getBaseToken(0), address(accountingToken));
    }
}
