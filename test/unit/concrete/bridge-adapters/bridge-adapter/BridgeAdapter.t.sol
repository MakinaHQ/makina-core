// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

import {Base_Test} from "test/base/Base.t.sol";

abstract contract BridgeAdapter_Unit_Concrete_Test is Base_Test {
    address public parent;

    IBridgeAdapter public bridgeAdapter;

    function setUp() public virtual override {
        Base_Test.setUp();
        parent = makeAddr("adapterParent");
    }
}
