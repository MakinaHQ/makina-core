// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";
import {VerificationFailed} from "@wormhole/sdk/libraries/QueryResponse.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IChainRegistry} from "src/interfaces/IChainRegistry.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {ITokenRegistry} from "src/interfaces/ITokenRegistry.sol";
import {CaliberAccountingCCQ} from "src/libraries/CaliberAccountingCCQ.sol";
import {MachineUtils} from "src/libraries/MachineUtils.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
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

    function test_RevertWhen_ReentrantCall() public {
        bytes memory response;
        IWormhole.Signature[] memory signatures;

        accountingToken.scheduleReenter(
            MockERC20.Type.Before,
            address(machine),
            abi.encodeCall(IMachine.updateSpokeCaliberAccountingData, (response, signatures))
        );

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        vm.prank(machineDepositor);
        machine.deposit(0, address(0), 0);
    }

    function test_RevertWhen_InvalidSignature() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
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

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
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

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
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

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        vm.stopPrank();

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);

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
        vm.expectRevert(MachineUtils.StaleData.selector);
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
        vm.expectRevert(MachineUtils.StaleData.selector);
        machine.updateSpokeCaliberAccountingData(response, signatures);
    }

    function test_RevertWhen_UnexpectedResultLength() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
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

    function test_RevertWhen_TokenNotRegistered() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        bytes[] memory bridgesIn = new bytes[](1);
        bridgesIn[0] = abi.encode(spokeAccountingTokenAddr, 1e18);
        bytes[] memory bridgesOut;

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, 1e18, bridgesIn, bridgesOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );

        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ITokenRegistry.LocalTokenNotRegistered.selector, spokeAccountingTokenAddr, SPOKE_CHAIN_ID
            )
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);
    }

    function test_UpdateSpokeCaliberAccountingData() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        vm.stopPrank();

        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );

        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );

        machine.updateSpokeCaliberAccountingData(response, signatures);

        (uint256 netAum, bytes[] memory positions, bytes[] memory baseTokens, uint256 timestamp) =
            machine.getSpokeCaliberDetailedAum(SPOKE_CHAIN_ID);
        assertEq(timestamp, blockTime);
        assertEq(netAum, queriedData.netAum);
        assertEq(positions.length, queriedData.positions.length);
        assertEq(baseTokens.length, queriedData.baseTokens.length);

        skip(1 days);

        (netAum, positions, baseTokens, timestamp) = machine.getSpokeCaliberDetailedAum(SPOKE_CHAIN_ID);
        assertEq(timestamp, blockTime);
        assertEq(netAum, queriedData.netAum);
        assertEq(positions.length, queriedData.positions.length);
        for (uint256 i = 0; i < queriedData.positions.length; i++) {
            assertEq(positions[i], queriedData.positions[i]);
        }
        assertEq(baseTokens.length, queriedData.baseTokens.length);
        for (uint256 i = 0; i < queriedData.baseTokens.length; i++) {
            assertEq(baseTokens[i], queriedData.baseTokens[i]);
        }
    }
}
