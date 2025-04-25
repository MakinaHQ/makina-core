// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBaseMakinaRegistry} from "src/interfaces/IBaseMakinaRegistry.sol";
import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";

import {Integration_Concrete_Test} from "../IntegrationConcrete.t.sol";

abstract contract BridgeController_Integration_Concrete_Test is Integration_Concrete_Test {
    IBaseMakinaRegistry public registry;
    IBridgeController public bridgeController;
    IBridgeAdapterFactory public bridgeAdapterFactory;

    function setUp() public virtual override {}
}
