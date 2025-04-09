// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberFactory} from "src/interfaces/ICaliberFactory.sol";
import {Caliber} from "src/caliber/Caliber.sol";

import {Integration_Concrete_Spoke_Test} from "../IntegrationConcrete.t.sol";

contract CaliberFactory_Integration_Concrete_Test is Integration_Concrete_Spoke_Test {
    function test_Getters() public view {
        assertEq(caliberFactory.registry(), address(spokeRegistry));
        assertEq(caliberFactory.isCaliber(address(0)), false);
    }

    function test_RevertWhen_CallerWithoutRole() public {
        ICaliber.CaliberInitParams memory params;
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliberFactory.createCaliber(params, address(0));
    }

    function test_DeployCaliber() public {
        address _hubMachine = makeAddr("hubMachine");
        address _flashLoanModule = makeAddr("flashLoanModule");
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
                    initialFlashLoanModule: _flashLoanModule,
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialAuthority: address(accessManager)
                }),
                _hubMachine
            )
        );
        assertEq(caliberFactory.isCaliber(address(caliber)), true);

        assertEq(ICaliberMailbox(caliber.hubMachineEndpoint()).caliber(), address(caliber));
        assertEq(IAccessManaged(caliber.hubMachineEndpoint()).authority(), address(accessManager));
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
        assertEq(caliber.allowedInstrRoot(), initialAllowedInstrRoot);
        assertEq(caliber.timelockDuration(), DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK);
        assertEq(caliber.maxPositionIncreaseLossBps(), DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS);
        assertEq(caliber.maxPositionDecreaseLossBps(), DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS);
        assertEq(caliber.maxSwapLossBps(), DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS);
        assertEq(caliber.flashLoanModule(), _flashLoanModule);
        assertEq(caliber.mechanic(), mechanic);
        assertEq(caliber.authority(), address(accessManager));

        assertEq(caliber.getPositionsLength(), 0);
        assertEq(caliber.getBaseTokensLength(), 1);
        assertEq(caliber.getBaseTokenAddress(0), address(accountingToken));
    }
}
