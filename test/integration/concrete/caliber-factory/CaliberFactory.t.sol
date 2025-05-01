// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberFactory} from "src/interfaces/ICaliberFactory.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {CaliberMailbox} from "src/caliber/CaliberMailbox.sol";

import {Integration_Concrete_Spoke_Test} from "../IntegrationConcrete.t.sol";

contract CaliberFactory_Integration_Concrete_Test is Integration_Concrete_Spoke_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        ICaliber.CaliberInitParams memory cParams;
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams;
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliberFactory.createCaliber(cParams, mgParams, address(0));
    }

    function test_DeployCaliber() public {
        address _hubMachine = makeAddr("hubMachine");
        bytes32 initialAllowedInstrRoot = bytes32("0x12345");

        vm.expectEmit(true, false, false, false, address(caliberFactory));
        emit ICaliberFactory.SpokeCaliberCreated(_hubMachine, address(0), address(0));
        vm.prank(dao);
        caliber = Caliber(
            caliberFactory.createCaliber(
                ICaliber.CaliberInitParams({
                    accountingToken: address(accountingToken),
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
                _hubMachine
            )
        );
        assertTrue(caliberFactory.isCaliber(address(caliber)));
        assertTrue(caliberFactory.isCaliberMailbox(caliber.hubMachineEndpoint()));

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

        assertEq(caliber.getPositionsLength(), 0);
        assertEq(caliber.getBaseTokensLength(), 1);
        assertEq(caliber.getBaseToken(0), address(accountingToken));
    }

    function test_CreateBridgeAdapter_RevertWhen_CallerNotCaliberMailbox() public {
        vm.expectRevert(ICaliberFactory.NotCaliberMailbox.selector);
        caliberFactory.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, "");
    }
}
