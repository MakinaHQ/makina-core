// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockMachineEndpoint} from "test/mocks/MockMachineEndpoint.sol";

import {Base_Test} from "test/base/Base.t.sol";

abstract contract BridgeAdapter_Integration_Concrete_Test is Base_Test {
    IBridgeAdapter.Bridge public bridgeId;

    MockMachineEndpoint public bridgeController1;
    MockMachineEndpoint public bridgeController2;

    IBridgeAdapter public bridgeAdapter1;
    IBridgeAdapter public bridgeAdapter2;

    MockERC20 public token1;
    MockERC20 public token2;

    uint256 public chainId1;
    uint256 public chainId2;

    function setUp() public virtual override {
        Base_Test.setUp();

        chainId1 = block.chainid;
        chainId2 = chainId1 + 1;

        bridgeController1 = new MockMachineEndpoint();
        bridgeController2 = new MockMachineEndpoint();

        token1 = new MockERC20("Token1", "T1", 18);
        token2 = new MockERC20("Token2", "T2", 18);
    }
}
