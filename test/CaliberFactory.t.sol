// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./BaseTest.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ICaliberInbox} from "../src/caliber/HubCaliberInbox.sol";
import {IOracleRegistry} from "../src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract CaliberFactoryTest is BaseTest {
    event CaliberDeployed(address indexed caliber);

    uint256 private constant PRICE_A_E = 150;

    MockPriceFeed private aPriceFeed1;

    address private hubMachineInbox;
    bytes32 private initialAllowedInstrRoot;

    function _setUp() public override {
        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
    }

    function test_cannotDeployCaliberWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliberFactory.deployCaliber(address(0), address(0), 0, 0, bytes32(0), 0, 0, address(0), address(0));
    }

    function test_deployCaliber() public {
        hubMachineInbox = makeAddr("HubMachineInbox");
        initialAllowedInstrRoot = bytes32("0x12345");

        vm.expectEmit(false, false, false, false, address(caliberFactory));
        emit CaliberDeployed(address(caliber));
        vm.prank(dao);
        caliber = Caliber(
            caliberFactory.deployCaliber(
                hubMachineInbox,
                address(accountingToken),
                accountingTokenPosID,
                DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                initialAllowedInstrRoot,
                DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                mechanic,
                securityCouncil
            )
        );
        assertEq(caliberFactory.isCaliber(address(caliber)), true);
        assertEq(caliberFactory.isCaliber(address(0)), false);

        assertEq(caliber.oracleRegistry(), address(oracleRegistry));
        assertEq(ICaliberInbox(caliber.inbox()).hubMachineInbox(), hubMachineInbox);
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
        assertEq(caliber.allowedInstrRoot(), initialAllowedInstrRoot);
        assertEq(caliber.timelockDuration(), DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK);
        assertEq(caliber.maxSwapLossBps(), DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS);
        assertEq(caliber.mechanic(), mechanic);
        assertEq(caliber.securityCouncil(), securityCouncil);
        assertEq(caliber.authority(), address(accessManager));

        assertEq(caliber.getPositionsLength(), 1);
        caliber.accountForBaseToken(accountingTokenPosID);
    }
}
