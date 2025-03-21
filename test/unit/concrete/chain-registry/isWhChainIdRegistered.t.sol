// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ChainRegistry_Unit_Concrete_Test} from "./ChainRegistry.t.sol";

contract IsWhChainIdRegistered_Unit_Concrete_Test is ChainRegistry_Unit_Concrete_Test {
    function test_FalseForUnregisteredChainId() public view {
        assertFalse(chainRegistry.isWhChainIdRegistered(0));
    }
}
