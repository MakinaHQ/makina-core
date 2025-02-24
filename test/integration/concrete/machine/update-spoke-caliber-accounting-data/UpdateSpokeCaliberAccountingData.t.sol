// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {ISpokeCaliberMailbox} from "src/interfaces/ISpokeCaliberMailbox.sol";
import {PerChainData} from "test/utils/WormholeQueryTestHelpers.sol";
import {WormholeQueryTestHelpers} from "test/utils/WormholeQueryTestHelpers.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract UpdateSpokeCaliberAccountingData_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        spokeCaliberMailboxAddr = makeAddr("spokeCaliberMailbox");

        vm.startPrank(dao);
        spokeMachineMailboxAddr = machine.createSpokeMailbox(SPOKE_CHAIN_ID);
        machine.setSpokeCaliberMailbox(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr);
        vm.stopPrank();
    }

    function test_RevertWhen_InvalidChainId() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ISpokeCaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingData(false, true);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            uint16(SPOKE_CHAIN_ID + 1), blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );

        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ISpokeCaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );

        vm.expectRevert(IMachine.InvalidChainId.selector);
        machine.updateSpokeCaliberAccountingData(response, signatures);
    }

    function test_RevertWhen_UnexpectedResultLength() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ISpokeCaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingData(false, true);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            uint16(SPOKE_CHAIN_ID), blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        perChainData[0].result = new bytes[](2);
        perChainData[0].result[0] = abi.encode(queriedData);

        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ISpokeCaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );

        vm.expectRevert(IMachine.UnexpectedResultLength.selector);
        machine.updateSpokeCaliberAccountingData(response, signatures);
    }

    function test_UpdateSpokeCaliberAccountingData() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ISpokeCaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingData(false, true);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            uint16(SPOKE_CHAIN_ID), blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );

        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ISpokeCaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );

        machine.updateSpokeCaliberAccountingData(response, signatures);

        IMachine.SpokeCaliberData memory caliberData = machine.getSpokeCaliberAccountingData(SPOKE_CHAIN_ID);
        assertEq(caliberData.timestamp, blockTime);
        assertEq(caliberData.chainId, SPOKE_CHAIN_ID);
        assertEq(caliberData.machineMailbox, spokeMachineMailboxAddr);
        assertEq(caliberData.netAum, queriedData.netAum);
        assertEq(caliberData.positions.length, queriedData.positions.length);
        assertEq(caliberData.totalReceivedFromHM.length, queriedData.totalReceivedFromHM.length);
        assertEq(caliberData.totalSentToHM.length, queriedData.totalSentToHM.length);
    }
}
