// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Base_Test} from "test/base/Base.t.sol";

abstract contract TokenRegistry_Unit_Concrete_Test is Base_Test {
    uint256 internal evmChainId;
    uint16 internal whChainId;

    function setUp() public virtual override {
        Base_Test.setUp();

        accessManager = _deployAccessManager(deployer, deployer);
        tokenRegistry = _deployTokenRegistry(address(accessManager), address(accessManager));

        _setupTokenRegistryAMFunctionRoles(accessManager, address(tokenRegistry));
        setupAccessManagerRolesAndOwnership();
    }
}
