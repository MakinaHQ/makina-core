// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {Machine} from "src/machine/Machine.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {HubDualMailbox} from "src/mailbox/HubDualMailbox.sol";
import {SpokeCaliberMailbox} from "src/mailbox/SpokeCaliberMailbox.sol";
import {SpokeMachineMailbox} from "src/mailbox/SpokeMachineMailbox.sol";

import {Base_Test} from "test/BaseTest.sol";

abstract contract Unit_Concrete_Test is Base_Test {
    MockERC20 public accountingToken;
    MockERC20 public baseToken;

    MockPriceFeed internal aPriceFeed1;

    function setUp() public virtual override {
        Base_Test.setUp();
        _coreSharedSetup();

        accountingToken = new MockERC20("accountingToken", "ACT", 18);
        baseToken = new MockERC20("baseToken", "BT", 18);

        aPriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
    }
}

abstract contract Unit_Concrete_Hub_Test is Unit_Concrete_Test {
    Machine public machine;
    Caliber public caliber;
    HubDualMailbox public hubDualMailbox;
    SpokeMachineMailbox public spokeMachineMailbox;

    function setUp() public virtual override {
        Unit_Concrete_Test.setUp();
        _hubSetup();

        (machine, caliber, hubDualMailbox) =
            _deployMachine(address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));
    }
}

abstract contract Unit_Concrete_Spoke_Test is Unit_Concrete_Test {
    Caliber public caliber;
    SpokeCaliberMailbox public spokeCaliberMailbox;

    function setUp() public virtual override {
        Unit_Concrete_Test.setUp();
        _spokeSetup();

        (caliber, spokeCaliberMailbox) =
            _deployCaliber(address(0), address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));
    }
}
