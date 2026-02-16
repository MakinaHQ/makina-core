// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {Integration_Concrete_Hub_Test} from "../IntegrationConcrete.t.sol";

abstract contract HubCoreFactory_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    PreDepositVault internal preDepositVault;

    bytes32 internal initialAllowedInstrRoot;

    address internal accountingAgent;

    function setUp() public virtual override {
        Integration_Concrete_Hub_Test.setUp();

        accountingAgent = makeAddr("accountingAgent");
    }
}
