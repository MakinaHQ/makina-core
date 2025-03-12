// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";
import "@wormhole/sdk/constants/Chains.sol" as WormholeChains;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberFactory} from "src/interfaces/ICaliberFactory.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {ISpokeCaliberMailbox} from "src/interfaces/ISpokeCaliberMailbox.sol";
import {Machine} from "src/machine/Machine.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {ChainsInfo} from "test/utils/ChainsInfo.sol";
import {PerChainData} from "test/utils/WormholeQueryTestHelpers.sol";
import {WormholeQueryTestHelpers} from "test/utils/WormholeQueryTestHelpers.sol";
import {WormholeCoreHijack} from "test/utils/WormholeCoreHijack.sol";

import {Fork_Test} from "./Fork.t.sol";

contract Machine_Fork_Test is Fork_Test {
    Machine public machine;
    Caliber public hubCaliber;
    Caliber public spokeCaliber;

    address user;

    function setUp() public {
        user = makeAddr("user");
    }

    function test_fork_Hub_USDC() public {
        hubChainId = ChainsInfo.CHAIN_ID_SEPOLIA;
        spokeChainIds.push(ChainsInfo.CHAIN_ID_BASE_SEPOLIA);
        _setUp();

        ForkData memory ethForkData = forksData[hubChainId];
        ForkData memory baseForkData = forksData[ChainsInfo.CHAIN_ID_BASE_SEPOLIA];

        ///
        /// SWITCH TO ETHEREUM
        ///

        vm.selectFork(ethForkData.forkId);

        // deploy machine
        vm.prank(ethForkData.dao);
        machine = Machine(
            hubCore.machineFactory.deployMachine(
                IMachine.MachineInitParams({
                    accountingToken: ethForkData.usdc,
                    initialMechanic: ethForkData.mechanic,
                    initialSecurityCouncil: ethForkData.securityCouncil,
                    initialAuthority: address(hubCore.accessManager),
                    depositor: address(0),
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    hubCaliberAccountingTokenPosID: HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID,
                    hubCaliberPosStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    hubCaliberAllowedInstrRoot: bytes32(""),
                    hubCaliberTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    hubCaliberMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    hubCaliberMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    hubCaliberMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    depositorOnlyMode: false,
                    shareTokenName: DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                    shareTokenSymbol: DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
                })
            )
        );
        hubCaliber = Caliber(ICaliberMailbox(machine.hubCaliberMailbox()).caliber());

        // user deposits 10000 usdc
        uint256 depositAmount = 10000e6;
        deal({token: ethForkData.usdc, to: user, give: depositAmount});
        vm.startPrank(user);
        IERC20(ethForkData.usdc).approve(address(machine), depositAmount);
        machine.deposit(depositAmount, user);
        vm.stopPrank();

        // mechanic transfers 2000 usdc to caliber
        vm.startPrank(ethForkData.mechanic);
        machine.transferToCaliber(ethForkData.usdc, depositAmount / 5, 0);
        vm.stopPrank();

        // check hub caliber aum
        (uint256 hubCaliberAum,) = hubCaliber.getPositionsValues();
        assertEq(hubCaliberAum, depositAmount / 5);

        // check machine aum
        uint256 machineAum = machine.updateTotalAum();
        assertEq(machineAum, depositAmount);

        // deploy mailbox for spoke caliber
        vm.prank(ethForkData.dao);
        address baseMachineMailbox = machine.createSpokeMailbox(ChainsInfo.CHAIN_ID_BASE_SEPOLIA);

        // upgrade wormhole core with devnet guardian
        address wormhole = machine.wormhole();
        WormholeCoreHijack.hijackWormholeCore(wormhole);

        ///
        /// SWITCH TO BASE
        ///

        vm.selectFork(baseForkData.forkId);

        // deploy spoke caliber
        vm.prank(baseForkData.dao);
        spokeCaliber = Caliber(
            spokeCores[ChainsInfo.CHAIN_ID_BASE_SEPOLIA].caliberFactory.deployCaliber(
                ICaliber.CaliberInitParams({
                    hubMachineEndpoint: baseMachineMailbox,
                    accountingToken: baseForkData.usdc,
                    accountingTokenPosId: SPOKE_CALIBER_ACCOUNTING_TOKEN_POS_ID,
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: bytes32(""),
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialMechanic: baseForkData.mechanic,
                    initialSecurityCouncil: baseForkData.securityCouncil,
                    initialAuthority: address(spokeCores[ChainsInfo.CHAIN_ID_BASE_SEPOLIA].accessManager)
                })
            )
        );
        address spokeCaliberMailbox = spokeCaliber.mailbox();

        // fund spoke caliber
        uint256 spokeCaliberFund = 5_000e6;
        deal({token: baseForkData.usdc, to: address(spokeCaliber), give: spokeCaliberFund});

        // check spoke caliber aum
        (uint256 spokeCaliberAum,) = spokeCaliber.getPositionsValues();
        assertEq(spokeCaliberAum, spokeCaliberFund);

        // read spoke caliber accounting data
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WormholeChains.CHAIN_ID_BASE_SEPOLIA,
            uint64(block.number),
            uint64(block.timestamp),
            spokeCaliber.mailbox(),
            abi.encode(ISpokeCaliberMailbox(spokeCaliber.mailbox()).getSpokeCaliberAccountingData())
        );
        (bytes memory response, IWormhole.Signature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ISpokeCaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );

        ///
        /// SWITCH TO ETHEREUM
        ///

        vm.selectFork(ethForkData.forkId);

        // set spoke caliber mailbox in machine mailbox
        vm.prank(ethForkData.dao);
        machine.setSpokeCaliberMailbox(ChainsInfo.CHAIN_ID_BASE_SEPOLIA, spokeCaliberMailbox);

        // write spoke caliber accounting data in machine
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // check machine aum
        machineAum = machine.updateTotalAum();
        assertEq(machineAum, depositAmount + spokeCaliberAum);
    }
}
