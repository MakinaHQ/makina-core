// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ChainRegistry} from "src/registries/ChainRegistry.sol";

import {Base_Test} from "test/base/Base.t.sol";

contract ChainRegistry_Unit_Concrete_Test is Base_Test {
    uint256 evmChainId;
    uint16 whChainId;

    ChainRegistry chainRegistry;

    function setUp() public virtual override {
        Base_Test.setUp();
        HubCore memory deployment = deployHubCore(deployer, dao, address(0));
        setupAccessManager(deployment.accessManager, dao);
        chainRegistry = deployment.chainRegistry;
    }
}
