// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {PerChainData} from "test/utils/WormholeQueryTestHelpers.sol";
import {WormholeQueryTestHelpers} from "test/utils/WormholeQueryTestHelpers.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract ResetBridgeCounters_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function setUp() public virtual override {
        Machine_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.resetBridgeCounters(0, address(0));
    }

    function test_RevertGiven_InvalidChainId() public {
        vm.expectRevert(IMachine.InvalidChainId.selector);
        vm.prank(dao);
        machine.resetBridgeCounters(0, address(0));
    }

    function test_ResetBridgeCounters_CountersAlreadyNull()
        public
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
    {
        address token = makeAddr("token");
        vm.expectEmit(true, true, false, false, address(machine));
        emit IMachine.ResetBridgeCounters(SPOKE_CHAIN_ID, token);
        vm.prank(dao);
        machine.resetBridgeCounters(SPOKE_CHAIN_ID, token);
    }

    function test_ResetBridgeCounters_UnblockAUMCalculation()
        public
        withForeignTokenRegistered(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr)
        withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr)
        withBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3)
        withSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr)
    {
        uint256 inputAmount = 1e18;
        // schedule and send outgoing bridge transfer
        deal(address(accountingToken), address(machine), inputAmount, true);
        address bridgeAdapter = machine.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
        uint256 transferId = IBridgeAdapter(bridgeAdapter).nextOutTransferId();
        vm.startPrank(mechanic);
        machine.transferToSpokeCaliber(
            IBridgeAdapter.Bridge.ACROSS_V3, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, inputAmount
        );
        machine.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId, abi.encode(1 days));
        vm.stopPrank();

        // cancel the transfer
        deal(address(accountingToken), bridgeAdapter, inputAmount, true);
        vm.prank(mechanic);
        machine.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        // simulate the machine transfer being received and claimed by spoke caliber
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData = _buildSpokeCaliberAccountingData(false);
        queriedData.bridgesIn = new bytes[](1);
        queriedData.bridgesIn[0] = abi.encode(spokeAccountingTokenAddr, inputAmount);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // aum update now reverts
        vm.expectRevert(IMachine.BridgeStateMismatch.selector);
        machine.updateTotalAum();

        // reset the bridge counters
        vm.prank(dao);
        machine.resetBridgeCounters(SPOKE_CHAIN_ID, address(accountingToken));

        // aum update now works
        machine.updateTotalAum();

        // simulate caliber notifying reset counters
        queriedData.bridgesIn = new bytes[](0);
        perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (response, signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // aum update still works
        machine.updateTotalAum();
    }
}
