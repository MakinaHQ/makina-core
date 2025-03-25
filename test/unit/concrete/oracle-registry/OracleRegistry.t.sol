// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MockERC20} from "test/mocks/MockERC20.sol";

import {Base_Test} from "test/base/Base.t.sol";

contract OracleRegistry_Unit_Concrete_Test is Base_Test {
    MockERC20 internal baseToken;
    MockERC20 internal quoteToken;

    function setUp() public virtual override {
        Base_Test.setUp();
        (accessManager, oracleRegistry,,) = deploySharedCore(deployer, dao);
        setupAccessManager(accessManager, dao);
    }
}
