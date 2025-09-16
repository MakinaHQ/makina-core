// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Base_Test} from "test/base/Base.t.sol";

abstract contract TokenRegistry_Unit_Concrete_Test is Base_Test {
    uint256 public evmChainId;
    uint16 public whChainId;

    function setUp() public virtual override {
        Base_Test.setUp();

        accessManager = _deployAccessManager(deployer, dao);
        tokenRegistry = _deployTokenRegistry(dao, address(accessManager));

        _setupTokenRegistryAMFunctionRoles(accessManager, address(tokenRegistry));
        setupAccessManagerRoles(accessManager, address(0), dao, address(0), address(0), address(0), deployer);
    }
}
