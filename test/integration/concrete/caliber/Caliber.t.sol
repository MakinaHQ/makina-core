// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Integration_Concrete_Hub_Test} from "../IntegrationConcrete.t.sol";

contract Caliber_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    function setUp() public virtual override {
        Integration_Concrete_Hub_Test.setUp();
        _setUpCaliberMerkleRoot(caliber);
    }
}
