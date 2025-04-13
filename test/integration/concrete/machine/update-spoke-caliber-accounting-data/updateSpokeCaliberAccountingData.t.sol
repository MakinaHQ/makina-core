// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";
import {VerificationFailed} from "@wormhole/sdk/libraries/QueryResponse.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IChainRegistry} from "src/interfaces/IChainRegistry.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {CaliberAccountingCCQ} from "src/libraries/CaliberAccountingCCQ.sol";
import {PerChainData} from "test/utils/WormholeQueryTestHelpers.sol";
import {WormholeQueryTestHelpers} from "test/utils/WormholeQueryTestHelpers.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract UpdateSpokeCaliberAccountingData_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.prank(dao);
        machine.setSpokeCaliber(
            SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new IBridgeAdapter.Bridge[](0), new address[](0)
        );
    }

    function test_RevertWhen_InvalidSignature() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false, true);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );

        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        signatures[0].v = 0;

        vm.expectRevert(VerificationFailed.selector);
        machine.updateSpokeCaliberAccountingData(response, signatures);
    }

    function test_RevertWhen_ChainIdNotRegistered() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false, true);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID + 1, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );

        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(IChainRegistry.WhChainIdNotRegistered.selector, WORMHOLE_SPOKE_CHAIN_ID + 1)
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);
    }

    function test_RevertWhen_InvalidChainId() public {
        vm.prank(dao);
        chainRegistry.setChainIds(SPOKE_CHAIN_ID + 1, WORMHOLE_SPOKE_CHAIN_ID + 1);

        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false, true);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID + 1, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );

        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );

        vm.expectRevert(IMachine.InvalidChainId.selector);
        machine.updateSpokeCaliberAccountingData(response, signatures);
    }

    function test_RevertWhen_InvalidFormat() public {
        bytes memory response;
        IWormhole.Signature[] memory signatures;

        vm.expectRevert();
        machine.updateSpokeCaliberAccountingData(response, signatures);
    }

    function test_RevertWhen_StaleData() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false, true);

        // data is stale according to machine's staleness threshold
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID,
            blockNum,
            blockTime - uint64(machine.caliberStaleThreshold()),
            spokeCaliberMailboxAddr,
            abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        vm.expectRevert(CaliberAccountingCCQ.StaleData.selector);
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // update data
        perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (response, signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // data is older than previous data
        perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime - 1, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (response, signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        vm.expectRevert(CaliberAccountingCCQ.StaleData.selector);
        machine.updateSpokeCaliberAccountingData(response, signatures);
    }

    function test_RevertWhen_UnexpectedResultLength() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false, true);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        perChainData[0].result = new bytes[](2);
        perChainData[0].result[0] = abi.encode(queriedData);

        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );

        vm.expectRevert(CaliberAccountingCCQ.UnexpectedResultLength.selector);
        machine.updateSpokeCaliberAccountingData(response, signatures);
    }

    function test_UpdateSpokeCaliberAccountingData() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false, true);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );

        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );

        machine.updateSpokeCaliberAccountingData(response, signatures);

        (ICaliberMailbox.SpokeCaliberAccountingData memory caliberData, uint256 timestamp) =
            machine.getSpokeCaliberAccountingData(SPOKE_CHAIN_ID);
        assertEq(timestamp, blockTime);
        assertEq(caliberData.netAum, queriedData.netAum);
        assertEq(caliberData.positions.length, queriedData.positions.length);
        assertEq(caliberData.baseTokens.length, queriedData.baseTokens.length);
        assertEq(caliberData.bridgesOut.length, queriedData.bridgesOut.length);
        assertEq(caliberData.bridgesIn.length, queriedData.bridgesIn.length);

        skip(1 days);

        (caliberData, timestamp) = machine.getSpokeCaliberAccountingData(SPOKE_CHAIN_ID);
        assertEq(timestamp, blockTime);
        assertEq(caliberData.netAum, queriedData.netAum);
        assertEq(caliberData.positions.length, queriedData.positions.length);
        for (uint256 i = 0; i < queriedData.positions.length; i++) {
            assertEq(caliberData.positions[i], queriedData.positions[i]);
        }
        assertEq(caliberData.baseTokens.length, queriedData.baseTokens.length);
        for (uint256 i = 0; i < queriedData.baseTokens.length; i++) {
            assertEq(caliberData.baseTokens[i], queriedData.baseTokens[i]);
        }
        assertEq(caliberData.bridgesOut.length, queriedData.bridgesOut.length);
        for (uint256 i = 0; i < queriedData.bridgesOut.length; i++) {
            assertEq(caliberData.bridgesOut[i], queriedData.bridgesOut[i]);
        }
        assertEq(caliberData.bridgesIn.length, queriedData.bridgesIn.length);
        for (uint256 i = 0; i < queriedData.bridgesIn.length; i++) {
            assertEq(caliberData.bridgesIn[i], queriedData.bridgesIn[i]);
        }
    }
}
