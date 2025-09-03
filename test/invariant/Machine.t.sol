// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMockAcrossV3SpokePool} from "test/mocks/IMockAcrossV3SpokePool.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {CaliberMailbox} from "src/caliber/CaliberMailbox.sol";
import {Machine} from "src/machine/Machine.sol";
import {MachineHandler} from "./handlers/MachineHandler.sol";
import {MachineStore} from "./stores/MachineStore.sol";

import {Base_CrossChain_Test} from "../base/Base.t.sol";

contract Machine_Invariant_Test is Base_CrossChain_Test {
    /// @dev A denotes the accounting token, B denotes the base token
    /// and E is the reference currency of the oracle registry.
    uint256 internal constant PRICE_A_E = 150;
    uint256 internal constant PRICE_B_E = 60000;
    uint256 internal constant PRICE_B_A = 400;

    uint256 public constant A_START_BALANCE = 1_000_000e18;
    uint256 public constant B_START_BALANCE = 2_000_000e18;

    uint16 public constant WORMHOLE_SPOKE_CHAIN_ID = 2000;

    uint256 public constant ACROSS_V3_FEE_BPS = 50;

    MockERC20 public accountingToken;
    MockERC20 public baseToken;

    IMockAcrossV3SpokePool internal acrossV3SpokePool;

    MockPriceFeed internal aPriceFeed1;
    MockPriceFeed internal bPriceFeed1;

    Machine public machine;
    Caliber public hubCaliber;

    Caliber public spokeCaliber;
    CaliberMailbox public spokeCaliberMailbox;

    MachineHandler public machineHandler;
    MachineStore public machineStore;

    function setUp() public virtual override {
        Base_CrossChain_Test.setUp();

        machineStore = new MachineStore();

        machineStore.setSpokeChainId(hubChainId);

        // deploy tokens and price feeds
        accountingToken = new MockERC20("accountingToken", "ACT", 18);
        baseToken = new MockERC20("baseToken", "BT", 18);

        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);
        bPriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_E * 1e18), block.timestamp);

        machineStore.addToken(address(accountingToken));
        machineStore.addToken(address(baseToken));

        // deploy Across V3 spoke pool
        acrossV3SpokePool = IMockAcrossV3SpokePool(deployMockAcrossV3SpokePoolViaIR());
        machineStore.setBridgeFeeBps(ACROSS_V3_BRIDGE_ID, ACROSS_V3_FEE_BPS);

        // set up registries
        vm.startPrank(dao);
        chainRegistry.setChainIds(machineStore.spokeChainId(), WORMHOLE_SPOKE_CHAIN_ID);
        tokenRegistry.setToken(address(accountingToken), machineStore.spokeChainId(), address(accountingToken));
        tokenRegistry.setToken(address(baseToken), machineStore.spokeChainId(), address(baseToken));
        oracleRegistry.setFeedRoute(
            address(accountingToken), address(aPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setFeedRoute(
            address(baseToken), address(bPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        hubCoreRegistry.setBridgeAdapterBeacon(
            ACROSS_V3_BRIDGE_ID, address(_deployAcrossV3BridgeAdapterBeacon(dao, address(acrossV3SpokePool)))
        );
        spokeCoreRegistry.setBridgeAdapterBeacon(
            ACROSS_V3_BRIDGE_ID, address(_deployAcrossV3BridgeAdapterBeacon(dao, address(acrossV3SpokePool)))
        );
        vm.stopPrank();

        // deploy hub and spoke chain contracts
        (machine, hubCaliber) = _deployMachine(address(accountingToken), bytes32(0), TEST_DEPLOYMENT_SALT);
        (spokeCaliber, spokeCaliberMailbox) = _deployCaliber(
            address(machine), address(accountingToken), bytes32(0), bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1)
        );

        // set up machine and spoke caliber
        vm.prank(riskManagerTimelock);
        spokeCaliber.addBaseToken(address(baseToken));

        vm.startPrank(dao);
        machine.setSpokeCaliber(
            machineStore.spokeChainId(), address(spokeCaliberMailbox), new uint16[](0), new address[](0)
        );
        address hubBridgeAdapterAddr = machine.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");
        address spokeBridgeAdapterAddr =
            spokeCaliberMailbox.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");
        machine.setSpokeBridgeAdapter(machineStore.spokeChainId(), ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr);
        spokeCaliberMailbox.setHubBridgeAdapter(ACROSS_V3_BRIDGE_ID, hubBridgeAdapterAddr);
        vm.stopPrank();

        machineHandler = new MachineHandler(machine, spokeCaliber, machineStore);

        targetContract(address(machineHandler));

        // set up machine balances
        deal(address(accountingToken), address(machine), A_START_BALANCE);

        deal(address(baseToken), address(hubCaliber), B_START_BALANCE);
        vm.prank(mechanic);
        hubCaliber.transferToHubMachine(address(baseToken), B_START_BALANCE, "");
    }

    function invariant_totalAum() public {
        uint256 totalATBridgeFee = machineStore.totalAccountedBridgeFee(address(accountingToken));
        uint256 totalBTBridgeFee = machineStore.totalAccountedBridgeFee(address(baseToken));

        assertEq(
            machine.updateTotalAum(),
            A_START_BALANCE - totalATBridgeFee + ((B_START_BALANCE - totalBTBridgeFee) * PRICE_B_A),
            "incorrect total AUM"
        );
    }
}
