// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {Integration_Concrete_Hub_Test} from "../IntegrationConcrete.t.sol";

contract MachineFactory_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    PreDepositVault public preDepositVault;

    bytes32 public initialAllowedInstrRoot;
}
