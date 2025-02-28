// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ChainsData} from "test/utils/ChainsData.sol";

import {Fork_Test} from "./Fork.t.sol";

contract Machine_Fork_Test is Fork_Test {
    function setUp() public {
        hubChainId = ChainsData.CHAIN_ID_ETHEREUM;
        spokeChainIds.push(ChainsData.CHAIN_ID_BASE);
        _setUp();
    }

    function test_fork() public {}
}
