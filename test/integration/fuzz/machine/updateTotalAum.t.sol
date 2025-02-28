// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {ISpokeCaliberMailbox} from "src/interfaces/ISpokeCaliberMailbox.sol";
import {Machine} from "src/machine/Machine.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {HubDualMailbox} from "src/mailbox/HubDualMailbox.sol";
import {Constants} from "src/libraries/Constants.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";
import {PerChainData} from "test/utils/WormholeQueryTestHelpers.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";
import {WormholeQueryTestHelpers} from "test/utils/WormholeQueryTestHelpers.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {MockSupplyModule} from "test/mocks/MockSupplyModule.sol";
import {MockBorrowModule} from "test/mocks/MockBorrowModule.sol";

import {Base_Hub_Test} from "test/base/Base.t.sol";

contract UpdateTotalAum_Integration_Fuzz_Test is Base_Hub_Test {
    uint256 public constant SPOKE_CHAIN_ID = 1000;

    uint256 internal constant VAULT_POS_ID = 3;
    uint256 internal constant SUPPLY_POS_ID = 4;
    uint256 internal constant BORROW_POS_ID = 5;
    uint256 internal constant POOL_POS_ID = 6;

    MockERC20 public accountingToken;
    MockERC20 public baseToken;

    MockSupplyModule internal supplyModule;
    MockBorrowModule internal borrowModule;

    Machine public machine;
    Caliber public caliber;
    HubDualMailbox public hubDualMailbox;

    address public spokeCaliberMailboxAddr;

    struct Data {
        uint8 aDecimals;
        uint8 bDecimals;
        uint8 af1Decimals;
        uint8 bf1Decimals;
        uint32 price_a_e;
        uint32 price_b_e;
        uint256 machineIdleAccountingTokens;
        uint256 machineIdleBaseTokens;
        uint256 hubCaliberNetAum;
        uint256 spokeCaliberNetAum;
    }
    // uint256 spokeCaliberTotalAccountingTokenReceivedFromHub;
    // uint256 spokeCaliberTotalBaseTokenReceivedFromHub;
    // uint256 spokeCaliberTotalAccountingTokenSentToHub;
    // uint256 spokeCaliberTotalBaseTokenSentToHub;

    function setUp() public override {
        Base_Hub_Test.setUp();
    }

    function _fuzzTestSetupAfter(Data memory data) public {
        data.aDecimals = uint8(bound(data.aDecimals, 6, 18));
        data.bDecimals = uint8(bound(data.bDecimals, 6, 18));
        data.af1Decimals = uint8(bound(data.af1Decimals, 6, 18));
        data.bf1Decimals = uint8(bound(data.bf1Decimals, 6, 18));
        data.price_a_e = uint32(bound(data.price_a_e, 1, 1e5));
        data.price_b_e = uint32(bound(data.price_b_e, 1, 1e5));
        data.machineIdleAccountingTokens = bound(data.machineIdleAccountingTokens, 0, 1e40);
        data.machineIdleBaseTokens = bound(data.machineIdleBaseTokens, 0, 1e40);
        data.hubCaliberNetAum = bound(data.hubCaliberNetAum, 0, 1e40);
        data.spokeCaliberNetAum = bound(data.spokeCaliberNetAum, 0, 1e40);

        accountingToken = new MockERC20("Accounting Token", "ACT", data.aDecimals);
        baseToken = new MockERC20("Base Token", "BT", data.bDecimals);

        supplyModule = new MockSupplyModule(IERC20(baseToken));
        borrowModule = new MockBorrowModule(IERC20(baseToken));

        MockPriceFeed aPriceFeed1 =
            new MockPriceFeed(data.af1Decimals, int256(data.price_a_e * (10 ** data.af1Decimals)), block.timestamp);
        MockPriceFeed bPriceFeed1 =
            new MockPriceFeed(data.bf1Decimals, int256(data.price_b_e * (10 ** data.bf1Decimals)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        (machine, caliber, hubDualMailbox) =
            _deployMachine(address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));

        spokeCaliberMailboxAddr = makeAddr("spokeCaliberMailbox");

        vm.startPrank(dao);
        machine.createSpokeMailbox(SPOKE_CHAIN_ID);
        machine.setSpokeCaliberMailbox(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr);
        vm.stopPrank();

        skip(caliber.timelockDuration() + 1);
    }

    function test_UpdateTotalAum_PositiveSpokeCaliberValue(Data memory data) public {
        _fuzzTestSetupAfter(data);

        if (data.machineIdleAccountingTokens > 0) {
            deal(address(accountingToken), address(machine), data.machineIdleAccountingTokens, true);
        }

        uint256 machineIdleBaseTokensValue;
        if (data.machineIdleBaseTokens > 0) {
            deal(address(baseToken), address(machine), data.machineIdleBaseTokens, true);
            vm.prank(address(hubDualMailbox));
            machine.notifyIncomingTransfer(address(baseToken));
            machineIdleBaseTokensValue = data.machineIdleBaseTokens
                * ((10 ** data.aDecimals) * data.price_b_e / data.price_a_e) / (10 ** data.bDecimals);
        }

        if (data.hubCaliberNetAum > 0) {
            deal(address(accountingToken), address(caliber), data.hubCaliberNetAum, true);
        }

        // update spoke caliber accounting data
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        ISpokeCaliberMailbox.SpokeCaliberAccountingData memory queriedData;
        queriedData.netAum = data.spokeCaliberNetAum;
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            uint16(SPOKE_CHAIN_ID), blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ISpokeCaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        machine.updateTotalAum();

        assertEq(
            machine.lastTotalAum(),
            data.machineIdleAccountingTokens + machineIdleBaseTokensValue + data.hubCaliberNetAum
                + data.spokeCaliberNetAum
        );
    }
}
