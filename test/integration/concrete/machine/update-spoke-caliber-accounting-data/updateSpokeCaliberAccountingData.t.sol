// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IMachine} from "src/interfaces/IMachine.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract UpdateSpokeCaliberAccountingData_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));
    }

    function test_RevertWhen_ReentrantCall() public {
        accountingToken.scheduleReenter(
            MockERC20.Type.Before, address(machine), abi.encodeCall(IMachine.updateSpokeCaliberAccountingData, (""))
        );

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(machineDepositor);
        machine.deposit(0, address(0), 0, 0);
    }

    function test_RevertWhen_InvalidChainId() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        bytes memory report = _buildSpokeCaliberAccountingReport(SPOKE_CHAIN_ID + 1, blockNum, blockTime, false);

        vm.expectRevert(Errors.InvalidChainId.selector);
        machine.updateSpokeCaliberAccountingData(report);
    }

    function test_RevertWhen_InvalidFormat() public {
        bytes memory report;

        vm.expectRevert();
        machine.updateSpokeCaliberAccountingData(report);
    }

    function test_RevertWhen_StaleData() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        vm.stopPrank();

        bytes memory report = _buildSpokeCaliberAccountingReport(
            SPOKE_CHAIN_ID, blockNum, blockTime - uint64(machine.caliberStaleThreshold()), false
        );

        vm.expectRevert(Errors.StaleData.selector);
        machine.updateSpokeCaliberAccountingData(report);

        // update data
        report = _buildSpokeCaliberAccountingReport(SPOKE_CHAIN_ID, blockNum, blockTime, false);
        machine.updateSpokeCaliberAccountingData(report);

        // data is older than previous data
        report = _buildSpokeCaliberAccountingReport(SPOKE_CHAIN_ID, blockNum, blockTime - 1, false);
        vm.expectRevert(Errors.StaleData.selector);
        machine.updateSpokeCaliberAccountingData(report);
    }

    function test_RevertWhen_TokenNotRegistered() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        bytes[] memory bridgesIn = new bytes[](1);
        bridgesIn[0] = abi.encode(spokeAccountingTokenAddr, 1e18);

        bytes memory report = _buildSpokeCaliberAccountingReportWithTransfers(
            SPOKE_CHAIN_ID, blockNum, blockTime, false, 1e18, bridgesIn, new bytes[](0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LocalTokenNotRegistered.selector, spokeAccountingTokenAddr, SPOKE_CHAIN_ID)
        );
        machine.updateSpokeCaliberAccountingData(report);
    }

    function test_UpdateSpokeCaliberAccountingData() public {
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        tokenRegistry.setToken(address(baseToken), SPOKE_CHAIN_ID, spokeBaseTokenAddr);
        vm.stopPrank();

        bytes memory report = _buildSpokeCaliberAccountingReport(SPOKE_CHAIN_ID, blockNum, blockTime, false);
        machine.updateSpokeCaliberAccountingData(report);

        (uint256 netAum, uint256 timestamp) = machine.getSpokeCaliberNetAum(SPOKE_CHAIN_ID);
        assertEq(timestamp, blockTime);
        assertEq(netAum, SPOKE_CALIBER_NET_AUM);

        skip(1 days);

        (netAum, timestamp) = machine.getSpokeCaliberNetAum(SPOKE_CHAIN_ID);
        assertEq(timestamp, blockTime);
        assertEq(netAum, SPOKE_CALIBER_NET_AUM);
    }
}
