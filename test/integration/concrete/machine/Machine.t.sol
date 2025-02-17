// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Integration_Concrete_Test} from "../IntegrationConcrete.t.sol";

contract Machine_Integration_Concrete_Test is Integration_Concrete_Test {
    function setUp() public virtual override {
        Integration_Concrete_Test.setUp();
        _setUpCaliberMerkleRoot();
    }
}
