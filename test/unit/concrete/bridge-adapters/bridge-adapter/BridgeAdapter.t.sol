// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

import {Base_Test} from "test/base/Base.t.sol";

abstract contract BridgeAdapter_Unit_Concrete_Test is Base_Test {
    address internal coreRegistry;
    address internal controller;

    IBridgeAdapter internal bridgeAdapter;

    function setUp() public virtual override {
        Base_Test.setUp();
        controller = makeAddr("bridgeController");
    }
}
