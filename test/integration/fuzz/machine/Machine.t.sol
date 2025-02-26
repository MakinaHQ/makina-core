// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Base_Test} from "test/BaseTest.sol";

contract Machine_Integration_Fuzz_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        _coreSharedSetup();
        _hubSetup();
    }
}
