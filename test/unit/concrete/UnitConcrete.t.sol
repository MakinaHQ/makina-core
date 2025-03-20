// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {Machine} from "src/machine/Machine.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {HubDualMailbox} from "src/mailboxes/HubDualMailbox.sol";
import {SpokeCaliberMailbox} from "src/mailboxes/SpokeCaliberMailbox.sol";

import {Base_Test, Base_Hub_Test, Base_Spoke_Test} from "test/base/Base.t.sol";

abstract contract Unit_Concrete_Test is Base_Test {
    MockERC20 public accountingToken;
    MockERC20 public baseToken;

    MockPriceFeed internal aPriceFeed1;

    function setUp() public virtual override {
        Base_Test.setUp();

        accountingToken = new MockERC20("accountingToken", "ACT", 18);
        baseToken = new MockERC20("baseToken", "BT", 18);

        aPriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();
    }
}

abstract contract Unit_Concrete_Hub_Test is Unit_Concrete_Test, Base_Hub_Test {
    uint256 public constant SPOKE_CHAIN_ID = 1000;
    uint16 public constant WORMHOLE_SPOKE_CHAIN_ID = 2000;

    Machine public machine;
    Caliber public caliber;
    HubDualMailbox public hubDualMailbox;

    function setUp() public virtual override(Unit_Concrete_Test, Base_Hub_Test) {
        Base_Hub_Test.setUp();
        Unit_Concrete_Test.setUp();

        (machine, caliber, hubDualMailbox) = _deployMachine(address(accountingToken), bytes32(0), address(0));
    }
}

abstract contract Unit_Concrete_Spoke_Test is Unit_Concrete_Test, Base_Spoke_Test {
    Caliber public caliber;
    SpokeCaliberMailbox public spokeCaliberMailbox;

    function setUp() public virtual override(Unit_Concrete_Test, Base_Spoke_Test) {
        Base_Spoke_Test.setUp();
        Unit_Concrete_Test.setUp();

        (caliber, spokeCaliberMailbox) = _deployCaliber(address(0), address(accountingToken), bytes32(0), address(0));
    }
}
