// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract GetSpokeCaliberAccountingData_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_ProvidedChainIdIsHubChainId() public {
        vm.expectRevert(IMachine.InvalidChainId.selector);
        machine.getSpokeCaliberAccountingData(block.chainid);
    }

    function test_RevertWhen_ProvidedChainIdIsUnregisteredSpokeChainId() public {
        vm.expectRevert(IMachine.InvalidChainId.selector);
        machine.getSpokeCaliberAccountingData(SPOKE_CHAIN_ID);
    }

    function test_GetSpokeCaliberAccountingData() public {
        vm.prank(dao);
        machine.setSpokeCaliber(
            SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new IBridgeAdapter.Bridge[](0), new address[](0)
        );
        // does not revert
        machine.getSpokeCaliberAccountingData(SPOKE_CHAIN_ID);
    }
}
