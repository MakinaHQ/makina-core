// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IBridgeAdapterFactory} from "../../src/interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {ISpokeSnapshotConsumer} from "src/interfaces/ISpokeSnapshotConsumer.sol";
import {Machine} from "src/machine/Machine.sol";
import {MockFeeManager} from "test/mocks/MockFeeManager.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {ChainsInfo} from "test/utils/ChainsInfo.sol";

import {Fork_Test} from "./Fork.t.sol";

interface ICreForwarder {
    function owner() external view returns (address);
    function addForwarder(address forwarder) external;
    function route(
        bytes32 transmissionId,
        address transmitter,
        address receiver,
        bytes calldata metadata,
        bytes calldata validatedReport
    ) external returns (bool);
}

contract Machine_Fork_Test is Fork_Test {
    Machine public machine;
    Caliber public hubCaliber;
    Caliber public spokeCaliber;

    address public machineDepositor;
    address public machineRedeemer;

    MockFeeManager internal feeManager;

    function setUp() public {
        machineDepositor = makeAddr("MachineDepositor");
        machineRedeemer = makeAddr("MachineRedeemer");
    }

    function test_fork_Hub_USDC() public {
        hubChainId = ChainsInfo.CHAIN_ID_ETHEREUM;
        spokeChainIds.push(ChainsInfo.CHAIN_ID_BASE);
        _setUp();

        ForkData memory ethForkData = forksData[hubChainId];
        ForkData memory baseForkData = forksData[ChainsInfo.CHAIN_ID_BASE];

        ///
        /// SWITCH TO ETHEREUM
        ///

        vm.selectFork(ethForkData.forkId);

        feeManager =
            new MockFeeManager(ethForkData.dao, DEFAULT_FEE_MANAGER_FIXED_FEE_RATE, DEFAULT_FEE_MANAGER_PERF_FEE_RATE);

        bytes32[] memory creWorkflowIds = new bytes32[](1);
        creWorkflowIds[0] = DEFAULT_CRE_WORKFLOW_ID;

        // deploy machine
        vm.prank(ethForkData.dao);
        machine = Machine(
            hubCore.hubCoreFactory
                .createMachine(
                    IMachine.MachineInitParams({
                        initialDepositor: machineDepositor,
                        initialRedeemer: machineRedeemer,
                        initialFeeManager: address(feeManager),
                        initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                        initialMaxFixedFeeAccrualRate: DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE,
                        initialMaxPerfFeeAccrualRate: DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE,
                        initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
                        initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                        initialMaxSharePriceChangeRate: type(uint256).max
                    }),
                    ICaliber.CaliberInitParams({
                        initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                        initialAllowedInstrRoot: bytes32(""),
                        initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                        initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                        initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                        initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                        initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION,
                        initialBaseTokens: new address[](0)
                    }),
                    IMakinaGovernable.MakinaGovernableInitParams({
                        initialMechanic: ethForkData.mechanic,
                        initialSecurityCouncil: ethForkData.securityCouncil,
                        initialRiskManager: address(0),
                        initialRiskManagerTimelock: address(0),
                        initialAuthority: address(hubCore.accessManager),
                        initialRestrictedAccountingMode: false,
                        initialAccountingAgents: new address[](0)
                    }),
                    ISpokeSnapshotConsumer.SpokeSnapshotConsumerInitParams({initialCreWorkflowIds: creWorkflowIds}),
                    new IBridgeAdapterFactory.BridgeAdapterInitParams[](0),
                    ethForkData.usdc,
                    DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                    DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL,
                    TEST_DEPLOYMENT_SALT,
                    true
                )
        );
        hubCaliber = Caliber(machine.hubCaliber());

        // machineDepositor deposits 10000 usdc
        uint256 depositAmount = 10000e6;
        deal({token: ethForkData.usdc, to: machineDepositor, give: depositAmount});
        vm.startPrank(machineDepositor);
        IERC20(ethForkData.usdc).approve(address(machine), depositAmount);
        uint256 receivedShares = machine.deposit(depositAmount, machineDepositor, 0, 0);
        vm.stopPrank();

        // mechanic transfers 2000 usdc to caliber
        vm.startPrank(ethForkData.mechanic);
        machine.transferToHubCaliber(ethForkData.usdc, depositAmount / 5);
        vm.stopPrank();

        // check hub caliber aum
        {
            (uint256 hubCaliberAum,,) = hubCaliber.getDetailedAum();
            assertEq(hubCaliberAum, depositAmount / 5);
        }

        // check machine aum
        assertEq(machine.updateTotalAum(), depositAmount);

        ///
        /// SWITCH TO BASE
        ///

        vm.selectFork(baseForkData.forkId);

        // deploy spoke caliber
        vm.prank(baseForkData.dao);
        spokeCaliber = Caliber(
            spokeCores[ChainsInfo.CHAIN_ID_BASE].spokeCoreFactory
                .createCaliber(
                    ICaliber.CaliberInitParams({
                        initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                        initialAllowedInstrRoot: bytes32(""),
                        initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                        initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                        initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                        initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                        initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION,
                        initialBaseTokens: new address[](0)
                    }),
                    IMakinaGovernable.MakinaGovernableInitParams({
                        initialMechanic: baseForkData.mechanic,
                        initialSecurityCouncil: baseForkData.securityCouncil,
                        initialRiskManager: address(0),
                        initialRiskManagerTimelock: address(0),
                        initialAuthority: address(spokeCores[ChainsInfo.CHAIN_ID_BASE].accessManager),
                        initialRestrictedAccountingMode: false,
                        initialAccountingAgents: new address[](0)
                    }),
                    new IBridgeAdapterFactory.BridgeAdapterInitParams[](0),
                    baseForkData.usdc,
                    TEST_DEPLOYMENT_SALT,
                    true
                )
        );
        address spokeCaliberMailbox = spokeCaliber.hubMachineEndpoint();

        // fund spoke caliber
        uint256 spokeCaliberFund = 5_000e6;
        deal({token: baseForkData.usdc, to: address(spokeCaliber), give: spokeCaliberFund});

        // check spoke caliber aum
        ICaliberMailbox.SpokeCaliberAccountingData[] memory snapshots =
            new ICaliberMailbox.SpokeCaliberAccountingData[](1);
        snapshots[0] = ICaliberMailbox(spokeCaliberMailbox).getSpokeCaliberAccountingData();

        uint256 spokeCaliberAum = snapshots[0].netAum;
        assertEq(spokeCaliberAum, spokeCaliberFund);

        ///
        /// SWITCH TO ETHEREUM
        ///

        vm.selectFork(ethForkData.forkId);
        skip(15 seconds);

        // register spoke caliber mailbox in machine
        vm.prank(ethForkData.dao);
        machine.setSpokeCaliber(ChainsInfo.CHAIN_ID_BASE, spokeCaliberMailbox, new uint16[](0), new address[](0));

        // relay spoke caliber accounting data to the machine through the CRE forwarder
        ICreForwarder forwarder = ICreForwarder(machine.creForwarder());
        address creTransmitter = makeAddr("CreTransmitter");
        vm.prank(forwarder.owner());
        forwarder.addForwarder(creTransmitter);

        bytes memory metadata = abi.encodePacked(DEFAULT_CRE_WORKFLOW_ID, bytes10(0), address(0), bytes2(0));
        vm.prank(creTransmitter);
        bool delivered =
            forwarder.route(bytes32(uint256(1)), creTransmitter, address(machine), metadata, abi.encode(snapshots));
        assertTrue(delivered);

        // check machine aum
        skip(1);
        assertEq(machine.updateTotalAum(), depositAmount + spokeCaliberAum);

        // machineDepositor transfers some shares to machineRedeemer
        uint256 sharesToRedeem = receivedShares / 2;
        uint256 expectedAssets = machine.convertToAssets(sharesToRedeem);
        vm.startPrank(machineDepositor);
        IERC20(machine.shareToken()).transfer(machineRedeemer, sharesToRedeem);
        vm.stopPrank();

        // machineRedeemer redeems shares
        vm.prank(machineRedeemer);
        machine.redeem(sharesToRedeem, machineRedeemer, 0);
        vm.stopPrank();

        assertEq(IERC20(ethForkData.usdc).balanceOf(machineRedeemer), expectedAssets);
        assertEq(machine.lastTotalAum(), depositAmount + spokeCaliberAum - expectedAssets);
    }
}
