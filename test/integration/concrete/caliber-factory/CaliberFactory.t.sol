// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IHubDualMailbox} from "src/interfaces/IHubDualMailbox.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {Base_Test} from "test/BaseTest.sol";

contract CaliberFactory_Integration_Concrete_Test is Base_Test {
    event CaliberDeployed(address indexed caliber);

    uint256 private constant PRICE_A_E = 150;

    MockPriceFeed private aPriceFeed1;

    function _setUp() public override {
        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
    }

    function test_getters() public view {
        assertEq(caliberFactory.registry(), address(hubRegistry));
        assertEq(caliberFactory.isCaliber(address(0)), false);
    }

    function test_cannotDeployCaliberWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliberFactory.deployCaliber(
            address(0), address(0), 0, 0, bytes32(0), 0, 0, 0, address(0), address(0), address(0)
        );
    }

    function test_deployCaliber() public {
        address _machine = makeAddr("machine");
        bytes32 initialAllowedInstrRoot = bytes32("0x12345");

        vm.expectEmit(false, false, false, false, address(caliberFactory));
        emit CaliberDeployed(address(0));
        vm.prank(dao);
        caliber = Caliber(
            caliberFactory.deployCaliber(
                _machine,
                address(accountingToken),
                accountingTokenPosId,
                DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                initialAllowedInstrRoot,
                DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS,
                DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                mechanic,
                securityCouncil,
                address(accessManager)
            )
        );
        assertEq(caliberFactory.isCaliber(address(caliber)), true);

        assertEq(IHubDualMailbox(caliber.mailbox()).machine(), _machine);
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
        assertEq(caliber.allowedInstrRoot(), initialAllowedInstrRoot);
        assertEq(caliber.timelockDuration(), DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK);
        assertEq(caliber.maxSwapLossBps(), DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS);
        assertEq(caliber.mechanic(), mechanic);
        assertEq(caliber.authority(), address(accessManager));

        assertEq(caliber.getPositionsLength(), 1);
        caliber.accountForBaseToken(accountingTokenPosId);
    }
}
