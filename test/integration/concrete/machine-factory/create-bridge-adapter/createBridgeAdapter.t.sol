// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineFactory} from "src/interfaces/IMachineFactory.sol";

import {MachineFactory_Integration_Concrete_Test} from "../MachineFactory.t.sol";

contract CreateBridgeAdapter_Integration_Concrete_Test is MachineFactory_Integration_Concrete_Test {
    function test_CreateBridgeAdapter_RevertWhen_CallerNotMachine() public {
        vm.expectRevert(IMachineFactory.NotMachine.selector);
        machineFactory.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, "");
    }
}
