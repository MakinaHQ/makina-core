// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Base_Test} from "test/base/Base.t.sol";

contract TokenRegistry_Unit_Concrete_Test is Base_Test {
    uint256 public evmChainId;
    uint16 public whChainId;

    function setUp() public virtual override {
        Base_Test.setUp();
        (accessManager,, tokenRegistry) = deploySharedCore(deployer, dao);
        setupAccessManager(accessManager, dao);
    }
}
