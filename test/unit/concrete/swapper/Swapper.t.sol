// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Base_Test} from "test/base/Base.t.sol";

contract Swapper_Unit_Concrete_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        (accessManager,, swapper) = deploySharedCore(deployer, dao);
        setupAccessManager(accessManager, dao);
    }
}
