// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainRegistry} from "src/registries/ChainRegistry.sol";

import {Base_Test} from "test/base/Base.t.sol";

contract ChainRegistry_Unit_Concrete_Test is Base_Test {
    uint256 public evmChainId;
    uint16 public whChainId;

    ChainRegistry public chainRegistry;

    function setUp() public virtual override {
        Base_Test.setUp();

        accessManager = _deployAccessManager(deployer, dao);
        chainRegistry = _deployChainRegistry(dao, address(accessManager));

        _setupChainRegistryAMFunctionRoles(accessManager, address(chainRegistry));
        setupAccessManagerRoles(accessManager, address(0), dao, address(0), address(0), address(0), deployer);
    }
}
