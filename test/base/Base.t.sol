// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";

import {Caliber} from "src/caliber/Caliber.sol";
import {CaliberFactory} from "src/factories/CaliberFactory.sol";
import {ChainRegistry} from "src/registries/ChainRegistry.sol";
import {ChainsInfo} from "../utils/ChainsInfo.sol";
import {Constants} from "../utils/Constants.sol";
import {HubDualMailbox} from "src/mailbox/HubDualMailbox.sol";
import {HubRegistry} from "src/registries/HubRegistry.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {Machine} from "src/machine/Machine.sol";
import {MachineFactory} from "src/factories/MachineFactory.sol";
import {MockWormhole} from "../mocks/MockWormhole.sol";
import {OracleRegistry} from "src/OracleRegistry.sol";
import {SpokeCaliberMailbox} from "src/mailbox/SpokeCaliberMailbox.sol";
import {SpokeRegistry} from "src/registries/SpokeRegistry.sol";
import {Swapper} from "src/swap/Swapper.sol";

import {Base} from "./Base.sol";

abstract contract Base_Test is Base, Constants, Test {
    address public deployer;

    uint256 public hubChainId;

    address public dao;
    address public mechanic;
    address public securityCouncil;

    AccessManager public accessManager;
    OracleRegistry public oracleRegistry;
    Swapper public swapper;

    function setUp() public virtual {
        deployer = address(this);
        dao = makeAddr("MakinaDAO");
        mechanic = makeAddr("Mechanic");
        securityCouncil = makeAddr("SecurityCouncil");
    }
}

abstract contract Base_Hub_Test is Base_Test {
    HubRegistry public hubRegistry;
    ChainRegistry public chainRegistry;
    MachineFactory public machineFactory;
    UpgradeableBeacon public machineBeacon;
    UpgradeableBeacon public hubCaliberBeacon;
    UpgradeableBeacon public hubDualMailboxBeacon;
    UpgradeableBeacon public spokeMachineMailboxBeacon;

    IWormhole public wormhole;

    address public machineDepositor = makeAddr("MachineDepositor");

    function setUp() public virtual override {
        Base_Test.setUp();
        hubChainId = block.chainid;
        _wormholeSetup();

        HubCore memory deployment = deployHubCore(deployer, dao, address(wormhole));
        accessManager = deployment.accessManager;
        oracleRegistry = deployment.oracleRegistry;
        swapper = deployment.swapper;
        hubRegistry = deployment.hubRegistry;
        chainRegistry = deployment.chainRegistry;
        machineFactory = deployment.machineFactory;
        machineBeacon = deployment.machineBeacon;
        hubDualMailboxBeacon = deployment.hubDualMailboxBeacon;
        hubCaliberBeacon = deployment.hubCaliberBeacon;
        spokeMachineMailboxBeacon = deployment.spokeMachineMailboxBeacon;

        setupHubRegistry(deployment);
        setupAccessManager(accessManager, dao);
    }

    function _wormholeSetup() public {
        wormhole = IWormhole(address(new MockWormhole(WORMHOLE_HUB_CHAIN_ID, hubChainId)));
    }

    function _deployMachine(address _accountingToken, bytes32 _allowedInstrMerkleRoot, address _flashLoanModule)
        public
        returns (Machine, Caliber, HubDualMailbox)
    {
        vm.prank(dao);
        Machine _machine = Machine(
            machineFactory.deployMachine(
                IMachine.MachineInitParams({
                    accountingToken: _accountingToken,
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialAuthority: address(accessManager),
                    initialDepositor: machineDepositor,
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    hubCaliberPosStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    hubCaliberAllowedInstrRoot: _allowedInstrMerkleRoot,
                    hubCaliberTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    hubCaliberMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    hubCaliberMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    hubCaliberMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    hubCaliberInitialFlashLoanModule: _flashLoanModule
                }),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );
        Caliber _caliber = Caliber(ICaliberMailbox(_machine.hubCaliberMailbox()).caliber());
        HubDualMailbox _mailbox = HubDualMailbox(_machine.hubCaliberMailbox());
        return (_machine, _caliber, _mailbox);
    }
}

abstract contract Base_Spoke_Test is Base_Test {
    SpokeRegistry public spokeRegistry;
    CaliberFactory public caliberFactory;
    UpgradeableBeacon public spokeCaliberBeacon;
    UpgradeableBeacon public spokeCaliberMailboxBeacon;

    function setUp() public virtual override {
        Base_Test.setUp();
        hubChainId = ChainsInfo.CHAIN_ID_ETHEREUM;

        SpokeCore memory deployment = deploySpokeCore(deployer, dao, hubChainId);
        accessManager = deployment.accessManager;
        oracleRegistry = deployment.oracleRegistry;
        swapper = deployment.swapper;
        spokeRegistry = deployment.spokeRegistry;
        caliberFactory = deployment.caliberFactory;
        spokeCaliberBeacon = deployment.spokeCaliberBeacon;
        spokeCaliberMailboxBeacon = deployment.spokeCaliberMailboxBeacon;

        setupSpokeRegistry(deployment);
        setupAccessManager(accessManager, dao);
    }

    function _deployCaliber(
        address _spokeMachineMailbox,
        address _accountingToken,
        bytes32 _allowedInstrMerkleRoot,
        address _flashLoanModule
    ) public returns (Caliber, SpokeCaliberMailbox) {
        vm.prank(dao);
        Caliber _caliber = Caliber(
            caliberFactory.deployCaliber(
                ICaliber.CaliberInitParams({
                    hubMachineEndpoint: _spokeMachineMailbox,
                    accountingToken: _accountingToken,
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: _allowedInstrMerkleRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialFlashLoanModule: _flashLoanModule,
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialAuthority: address(accessManager)
                })
            )
        );
        SpokeCaliberMailbox _mailbox = SpokeCaliberMailbox(_caliber.mailbox());
        return (_caliber, _mailbox);
    }
}
