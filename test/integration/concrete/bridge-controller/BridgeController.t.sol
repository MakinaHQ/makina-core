// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";
import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";

import {Integration_Concrete_Test} from "../IntegrationConcrete.t.sol";

abstract contract BridgeController_Integration_Concrete_Test is Integration_Concrete_Test {
    ICoreRegistry internal registry;
    IBridgeController internal bridgeController;
    IBridgeAdapterFactory internal bridgeAdapterFactory;

    function setUp() public virtual override {}
}
