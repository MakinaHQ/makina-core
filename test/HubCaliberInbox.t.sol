// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./BaseTest.sol";
import {HubCaliberInbox, ICaliberInbox} from "../src/caliber/HubCaliberInbox.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract HubCaliberInboxTest is BaseTest {
    MockPriceFeed private aPriceFeed1;
    MockPriceFeed private bPriceFeed1;

    MockERC20 private baseToken;
    MockERC20 private baseToken2;

    address private hubMachineInbox;

    HubCaliberInbox private caliberInbox;

    function _setUp() public override {
        baseToken = new MockERC20("baseToken", "BT", 18);
        baseToken2 = new MockERC20("baseToken2", "BT2", 18);

        aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);
        bPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        hubMachineInbox = makeAddr("HubMachineInbox");

        caliber = _deployCaliber(hubMachineInbox, address(accountingToken), accountingTokenPosID, bytes32(0));

        caliberInbox = HubCaliberInbox(caliber.inbox());
    }

    function test_caliberInbox_getters() public view {
        assertEq(caliberInbox.hubMachineInbox(), address(hubMachineInbox));
        assertEq(caliberInbox.caliber(), address(caliber));
    }

    function test_cannotNotifyAmountFromHubMachineWithoutHubMachineInbox() public {
        vm.expectRevert(HubCaliberInbox.NotHMInbox.selector);
        caliberInbox.notifyAmountFromHubMachine(address(accountingToken), 1e18);
    }

    function test_notifyAmountFromHubMachine() public {
        vm.startPrank(hubMachineInbox);

        // hubMachineInbox sends 0 to caliberInbox
        caliberInbox.notifyAmountFromHubMachine(address(accountingToken), 0);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(accountingToken)), 0);

        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(hubMachineInbox), 2 * inputAmount, true);

        // hubMachineInbox sends funds to caliberInbox
        accountingToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(accountingToken), inputAmount);
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(accountingToken)), inputAmount);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(accountingToken)), 0);

        // hubMachineInbox sends funds to caliberInbox again
        accountingToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(accountingToken), inputAmount);
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(accountingToken)), 2 * inputAmount);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(accountingToken)), 0);
    }

    function test_cannotWithdrawPendingReceivedAmountsWithoutCaliber() public {
        vm.expectRevert(ICaliberInbox.NotCaliber.selector);
        caliberInbox.withdrawPendingReceivedAmounts();
    }

    function test_withdrawPendingReceivedAmounts() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(hubMachineInbox), 2 * inputAmount, true);
        deal(address(baseToken), address(hubMachineInbox), 2 * inputAmount, true);
        deal(address(baseToken2), address(hubMachineInbox), 2 * inputAmount, true);

        // hubMachineInbox sends non-base token amount to caliberInbox
        vm.startPrank(address(hubMachineInbox));
        baseToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(baseToken), inputAmount);

        // hubMachineInbox sends accountingToken amount to caliberInbox
        accountingToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(accountingToken), inputAmount);

        // hubMachineInbox sends other non-base token amount to caliberInbox
        baseToken2.approve(address(caliberInbox), inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(baseToken2), inputAmount);
        vm.stopPrank();

        // check accountingToken amount is transferred to caliber but non-base token amount is not
        vm.prank(address(caliber));
        caliberInbox.withdrawPendingReceivedAmounts();
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(accountingToken)), 0);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(accountingToken)), inputAmount);
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(baseToken)), inputAmount);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(baseToken)), 0);
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(baseToken2)), inputAmount);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(baseToken2)), 0);
        assertEq(accountingToken.balanceOf(address(caliberInbox)), 0);
        assertEq(accountingToken.balanceOf(address(caliber)), inputAmount);
        assertEq(baseToken.balanceOf(address(caliberInbox)), inputAmount);
        assertEq(baseToken.balanceOf(address(caliber)), 0);
        assertEq(baseToken2.balanceOf(address(caliberInbox)), inputAmount);
        assertEq(baseToken2.balanceOf(address(caliber)), 0);

        // check further withdrawal has no effect
        vm.prank(address(caliber));
        caliberInbox.withdrawPendingReceivedAmounts();
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(accountingToken)), 0);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(accountingToken)), inputAmount);
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(baseToken)), inputAmount);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(baseToken)), 0);
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(baseToken2)), inputAmount);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(baseToken2)), 0);
        assertEq(accountingToken.balanceOf(address(caliberInbox)), 0);
        assertEq(accountingToken.balanceOf(address(caliber)), inputAmount);
        assertEq(baseToken.balanceOf(address(caliberInbox)), inputAmount);
        assertEq(baseToken.balanceOf(address(caliber)), 0);
        assertEq(baseToken2.balanceOf(address(caliberInbox)), inputAmount);
        assertEq(baseToken2.balanceOf(address(caliber)), 0);

        // register base token in caliber
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 4);

        // check base token amount is now transferred to caliber
        vm.prank(address(caliber));
        caliberInbox.withdrawPendingReceivedAmounts();
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(accountingToken)), 0);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(accountingToken)), inputAmount);
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(baseToken)), 0);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(baseToken)), inputAmount);
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(baseToken2)), inputAmount);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(baseToken2)), 0);
        assertEq(baseToken.balanceOf(address(caliberInbox)), 0);
        assertEq(baseToken.balanceOf(address(caliber)), inputAmount);
        assertEq(baseToken2.balanceOf(address(caliberInbox)), inputAmount);
        assertEq(baseToken2.balanceOf(address(caliber)), 0);

        // hubMachineInbox sends funds to caliberInbox again
        vm.startPrank(address(hubMachineInbox));
        accountingToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(accountingToken), inputAmount);
        baseToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(baseToken), inputAmount);
        baseToken2.approve(address(caliberInbox), inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(baseToken2), inputAmount);
        vm.stopPrank();

        // check tokens are transferred to caliber
        vm.prank(address(caliber));
        caliberInbox.withdrawPendingReceivedAmounts();
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(accountingToken)), 0);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(accountingToken)), 2 * inputAmount);
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(baseToken)), 0);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(baseToken)), 2 * inputAmount);
        assertEq(caliberInbox.pendingReceivedFromHubMachine(address(baseToken2)), 2 * inputAmount);
        assertEq(caliberInbox.totalReceivedFromHubMachine(address(baseToken2)), 0);
        assertEq(accountingToken.balanceOf(address(caliberInbox)), 0);
        assertEq(accountingToken.balanceOf(address(caliber)), 2 * inputAmount);
        assertEq(baseToken.balanceOf(address(caliberInbox)), 0);
        assertEq(baseToken.balanceOf(address(caliber)), 2 * inputAmount);
        assertEq(baseToken2.balanceOf(address(caliberInbox)), 2 * inputAmount);
        assertEq(baseToken2.balanceOf(address(caliber)), 0);
    }

    function test_cannotInitTransferToHubMachineWithoutCaliber() public {
        vm.expectRevert(ICaliberInbox.NotCaliber.selector);
        caliberInbox.initTransferToHubMachine(address(accountingToken), 1e18);
    }

    function test_initTransferToHubMachine() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), 2 * inputAmount, true);

        // caliber sends funds to hubMachineInbox
        vm.startPrank(address(caliber));
        accountingToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.initTransferToHubMachine(address(accountingToken), inputAmount);
        vm.stopPrank();

        assertEq(caliberInbox.totalSentToHubMachine(address(accountingToken)), inputAmount);

        // caliber sends funds to hubMachineInbox again
        vm.startPrank(address(caliber));
        accountingToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.initTransferToHubMachine(address(accountingToken), inputAmount);
        vm.stopPrank();

        assertEq(caliberInbox.totalSentToHubMachine(address(accountingToken)), 2 * inputAmount);
    }

    function test_cannotRelayAccountingWithoutCaliber() public {
        vm.expectRevert(ICaliberInbox.NotCaliber.selector);
        caliberInbox.relayAccounting(0);
    }

    function test_relayAccounting() public {
        // no received or sent assets by caliberInbox
        vm.prank(address(caliber));
        ICaliberInbox.AccountingMessageSlim memory accMessage = caliberInbox.relayAccounting(1);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 1);
        assertEq(accMessage.totalReceivedFromHM.length, 0);
        assertEq(accMessage.totalSentToHM.length, 0);

        uint256 inputAmount = 1e18;

        // hubMachineInbox sends (2 * inputAmount) accountingToken to caliberInbox
        deal(address(accountingToken), address(hubMachineInbox), 2 * inputAmount, true);
        vm.startPrank(address(hubMachineInbox));
        accountingToken.approve(address(caliberInbox), 2 * inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(accountingToken), 2 * inputAmount);
        vm.stopPrank();

        skip(1 hours);

        // cumulative tokens received by caliber:
        // - none
        // cumulative tokens sent by caliber:
        // - none
        vm.prank(address(caliber));
        accMessage = caliberInbox.relayAccounting(2);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 2);
        assertEq(accMessage.totalReceivedFromHM.length, 0);
        assertEq(accMessage.totalSentToHM.length, 0);

        // caliber pulls pending received amounts from caliberInbox
        vm.prank(address(caliber));
        caliberInbox.withdrawPendingReceivedAmounts();

        skip(1 hours);

        // cumulative tokens received by caliber:
        // - accountingToken (2 * inputAmount)
        // cumulative tokens sent by caliber:
        // - none
        vm.prank(address(caliber));
        accMessage = caliberInbox.relayAccounting(2);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 2);
        assertEq(accMessage.totalReceivedFromHM.length, 1);
        assertEq(accMessage.totalReceivedFromHM[0], abi.encode(address(accountingToken), 2 * inputAmount));
        assertEq(accMessage.totalSentToHM.length, 0);

        // caliber sends inputAmount accountingToken to hubMachineInbox
        vm.startPrank(address(caliber));
        accountingToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.initTransferToHubMachine(address(accountingToken), inputAmount);
        vm.stopPrank();

        skip(1 hours);

        // cumulative tokens received by caliber:
        // - accountingToken (2 * inputAmount)
        // cumulative tokens sent by caliber:
        // - accountingToken (inputAmount)
        vm.prank(address(caliber));
        accMessage = caliberInbox.relayAccounting(2);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 2);
        assertEq(accMessage.totalReceivedFromHM.length, 1);
        assertEq(accMessage.totalReceivedFromHM[0], abi.encode(address(accountingToken), 2 * inputAmount));
        assertEq(accMessage.totalSentToHM.length, 1);
        assertEq(accMessage.totalSentToHM[0], abi.encode(address(accountingToken), inputAmount));

        // hubMachineInbox sends inputAmount accountingToken to caliberInbox
        deal(address(accountingToken), address(hubMachineInbox), inputAmount, true);
        vm.startPrank(address(hubMachineInbox));
        accountingToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(accountingToken), inputAmount);
        vm.stopPrank();

        skip(1 hours);

        // cumulative tokens received by caliber:
        // - accountingToken (2 * inputAmount)
        // cumulative tokens sent by caliber:
        // - accountingToken (inputAmount)
        vm.prank(address(caliber));
        accMessage = caliberInbox.relayAccounting(2);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 2);
        assertEq(accMessage.totalReceivedFromHM.length, 1);
        assertEq(accMessage.totalReceivedFromHM[0], abi.encode(address(accountingToken), 2 * inputAmount));
        assertEq(accMessage.totalSentToHM.length, 1);
        assertEq(accMessage.totalSentToHM[0], abi.encode(address(accountingToken), inputAmount));

        // caliber pulls pending received amounts from caliberInbox
        vm.prank(address(caliber));
        caliberInbox.withdrawPendingReceivedAmounts();

        skip(1 hours);

        // cumulative tokens received by caliber:
        // - accountingToken (3 * inputAmount)
        // cumulative tokens sent by caliber:
        // - accountingToken (inputAmount)
        vm.prank(address(caliber));
        accMessage = caliberInbox.relayAccounting(2);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 2);
        assertEq(accMessage.totalReceivedFromHM.length, 1);
        assertEq(accMessage.totalReceivedFromHM[0], abi.encode(address(accountingToken), 3 * inputAmount));
        assertEq(accMessage.totalSentToHM.length, 1);
        assertEq(accMessage.totalSentToHM[0], abi.encode(address(accountingToken), inputAmount));

        // caliber sends inputAmount accountingToken to hubMachineInbox
        vm.startPrank(address(caliber));
        accountingToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.initTransferToHubMachine(address(accountingToken), inputAmount);
        vm.stopPrank();

        skip(1 hours);

        // cumulative tokens received by caliber:
        // - accountingToken (3 * inputAmount)
        // cumulative tokens sent by caliber:
        // - accountingToken (2 * inputAmount)
        vm.prank(address(caliber));
        accMessage = caliberInbox.relayAccounting(2);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 2);
        assertEq(accMessage.totalReceivedFromHM.length, 1);
        assertEq(accMessage.totalReceivedFromHM[0], abi.encode(address(accountingToken), 3 * inputAmount));
        assertEq(accMessage.totalSentToHM.length, 1);
        assertEq(accMessage.totalSentToHM[0], abi.encode(address(accountingToken), 2 * inputAmount));

        // hubMachineInbox sends (2 * inputAmount) non-base token to caliberInbox
        deal(address(baseToken), address(hubMachineInbox), 2 * inputAmount, true);
        vm.startPrank(address(hubMachineInbox));
        baseToken.approve(address(caliberInbox), 2 * inputAmount);
        caliberInbox.notifyAmountFromHubMachine(address(baseToken), 2 * inputAmount);
        vm.stopPrank();

        skip(1 hours);

        // cumulative tokens received by caliber:
        // - accountingToken (3 * inputAmount)
        // cumulative tokens sent by caliber:
        // - accountingToken (2 * inputAmount)
        vm.prank(address(caliber));
        accMessage = caliberInbox.relayAccounting(2);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 2);
        assertEq(accMessage.totalReceivedFromHM.length, 1);
        assertEq(accMessage.totalReceivedFromHM[0], abi.encode(address(accountingToken), 3 * inputAmount));
        assertEq(accMessage.totalSentToHM.length, 1);
        assertEq(accMessage.totalSentToHM[0], abi.encode(address(accountingToken), 2 * inputAmount));

        // caliber pulls pending received amounts from caliberInbox (nothing happens, pending token is non-base)
        vm.prank(address(caliber));
        caliberInbox.withdrawPendingReceivedAmounts();

        skip(1 hours);

        // cumulative tokens received by caliber:
        // - accountingToken (3 * inputAmount)
        // cumulative tokens sent by caliber:
        // - accountingToken (2 * inputAmount)
        vm.prank(address(caliber));
        accMessage = caliberInbox.relayAccounting(2);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 2);
        assertEq(accMessage.totalReceivedFromHM.length, 1);
        assertEq(accMessage.totalReceivedFromHM[0], abi.encode(address(accountingToken), 3 * inputAmount));
        assertEq(accMessage.totalSentToHM.length, 1);
        assertEq(accMessage.totalSentToHM[0], abi.encode(address(accountingToken), 2 * inputAmount));

        // register base token in caliber
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 4);

        // caliber pulls pending received amounts from caliberInbox
        vm.prank(address(caliber));
        caliberInbox.withdrawPendingReceivedAmounts();

        skip(1 hours);

        // cumulative tokens received by caliber:
        // - accountingToken (3 * inputAmount)
        // - baseToken (2 * inputAmount)
        // cumulative tokens sent by caliber:
        // - accountingToken (2 * inputAmount)
        vm.prank(address(caliber));
        accMessage = caliberInbox.relayAccounting(2);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 2);
        assertEq(accMessage.totalReceivedFromHM.length, 2);
        assertEq(accMessage.totalReceivedFromHM[0], abi.encode(address(accountingToken), 3 * inputAmount));
        assertEq(accMessage.totalReceivedFromHM[1], abi.encode(address(baseToken), 2 * inputAmount));
        assertEq(accMessage.totalSentToHM.length, 1);
        assertEq(accMessage.totalSentToHM[0], abi.encode(address(accountingToken), 2 * inputAmount));

        // caliber sends inputAmount accountingToken to hubMachineInbox
        vm.startPrank(address(caliber));
        baseToken.approve(address(caliberInbox), inputAmount);
        caliberInbox.initTransferToHubMachine(address(baseToken), inputAmount);
        vm.stopPrank();

        skip(1 hours);

        // cumulative tokens received by caliber:
        // - accountingToken (3 * inputAmount)
        // - baseToken (2 * inputAmount)
        // cumulative tokens sent by caliber:
        // - accountingToken (2 * inputAmount)
        // - baseToken (inputAmount)
        vm.prank(address(caliber));
        accMessage = caliberInbox.relayAccounting(2);
        assertEq(accMessage.lastAccountingTime, block.timestamp);
        assertEq(accMessage.totalAccountingTokenValue, 2);
        assertEq(accMessage.totalReceivedFromHM.length, 2);
        assertEq(accMessage.totalReceivedFromHM[0], abi.encode(address(accountingToken), 3 * inputAmount));
        assertEq(accMessage.totalReceivedFromHM[1], abi.encode(address(baseToken), 2 * inputAmount));
        assertEq(accMessage.totalSentToHM.length, 2);
        assertEq(accMessage.totalSentToHM[0], abi.encode(address(accountingToken), 2 * inputAmount));
        assertEq(accMessage.totalSentToHM[1], abi.encode(address(baseToken), inputAmount));
    }
}
