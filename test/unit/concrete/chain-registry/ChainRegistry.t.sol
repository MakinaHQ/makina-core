// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainRegistry} from "src/registries/ChainRegistry.sol";

import {Base_Test} from "test/base/Base.t.sol";

contract ChainRegistry_Unit_Concrete_Test is Base_Test {
    uint256 internal evmChainId;
    uint16 internal whChainId;

    ChainRegistry internal chainRegistry;

    function setUp() public virtual override {
        Base_Test.setUp();

        accessManager = _deployAccessManager(deployer, deployer);
        chainRegistry = _deployChainRegistry(address(accessManager), address(accessManager));

        _setupChainRegistryAMFunctionRoles(accessManager, address(chainRegistry));
        setupAccessManagerRolesAndOwnership();
    }
}
