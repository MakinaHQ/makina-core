// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MockERC20} from "test/mocks/MockERC20.sol";

import {Base_Test} from "test/base/Base.t.sol";

abstract contract OracleRegistry_Unit_Concrete_Test is Base_Test {
    MockERC20 internal baseToken;
    MockERC20 internal quoteToken;

    function setUp() public virtual override {
        Base_Test.setUp();

        accessManager = _deployAccessManager(deployer, deployer);
        oracleRegistry = _deployOracleRegistry(address(accessManager), address(accessManager));

        _setupOracleRegistryAMFunctionRoles(accessManager, address(oracleRegistry));
        setupAccessManagerRolesAndOwnership();
    }
}
