// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainRegistry_Unit_Concrete_Test} from "./ChainRegistry.t.sol";

contract IsEvmChainIdRegistered_Unit_Concrete_Test is ChainRegistry_Unit_Concrete_Test {
    function test_FalseForUnregisteredChainId() public view {
        assertFalse(chainRegistry.isEvmChainIdRegistered(0));
    }
}
