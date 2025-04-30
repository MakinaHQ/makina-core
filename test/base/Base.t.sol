// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";

import {Caliber} from "src/caliber/Caliber.sol";
import {CaliberFactory} from "src/factories/CaliberFactory.sol";
import {CaliberMailbox} from "src/caliber/CaliberMailbox.sol";
import {ChainRegistry} from "src/registries/ChainRegistry.sol";
import {ChainsInfo} from "../utils/ChainsInfo.sol";
import {Constants} from "../utils/Constants.sol";
import {HubRegistry} from "src/registries/HubRegistry.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {Machine} from "src/machine/Machine.sol";
import {MachineFactory} from "src/factories/MachineFactory.sol";
import {MockFeeManager} from "../mocks/MockFeeManager.sol";
import {MockWormhole} from "../mocks/MockWormhole.sol";
import {OracleRegistry} from "src/registries/OracleRegistry.sol";
import {SpokeRegistry} from "src/registries/SpokeRegistry.sol";
import {SwapModule} from "src/swap/SwapModule.sol";
import {TokenRegistry} from "src/registries/TokenRegistry.sol";

import {Base} from "./Base.sol";

abstract contract Base_Test is Base, Constants, Test {
    address public deployer;

    uint256 public hubChainId;

    address public dao;
    address public mechanic;
    address public securityCouncil;
    address public riskManager;
    address public riskManagerTimelock;

    AccessManager public accessManager;
    OracleRegistry public oracleRegistry;
    TokenRegistry public tokenRegistry;
    SwapModule public swapModule;

    UpgradeableBeacon public caliberBeacon;

    function setUp() public virtual {
        deployer = address(this);
        dao = makeAddr("MakinaDAO");
        mechanic = makeAddr("Mechanic");
        securityCouncil = makeAddr("SecurityCouncil");
        riskManager = makeAddr("RiskManager");
        riskManagerTimelock = makeAddr("RiskManagerTimelock");
    }
}

abstract contract Base_Hub_Test is Base_Test {
    HubRegistry public hubRegistry;
    ChainRegistry public chainRegistry;
    MachineFactory public machineFactory;
    UpgradeableBeacon public machineBeacon;
    UpgradeableBeacon public preDepositVaultBeacon;

    IWormhole public wormhole;

    address public machineDepositor = makeAddr("MachineDepositor");
    address public machineRedeemer = makeAddr("MachineRedeemer");

    MockFeeManager public feeManager;

    function setUp() public virtual override {
        Base_Test.setUp();
        hubChainId = block.chainid;
        _wormholeSetup();

        HubCore memory deployment = deployHubCore(deployer, dao, address(wormhole));
        accessManager = deployment.accessManager;
        oracleRegistry = deployment.oracleRegistry;
        swapModule = deployment.swapModule;
        hubRegistry = deployment.hubRegistry;
        tokenRegistry = deployment.tokenRegistry;
        chainRegistry = deployment.chainRegistry;
        machineFactory = deployment.machineFactory;
        caliberBeacon = deployment.caliberBeacon;
        machineBeacon = deployment.machineBeacon;
        preDepositVaultBeacon = deployment.preDepositVaultBeacon;

        setupHubRegistry(deployment);
        setupAccessManager(accessManager, dao);
    }

    function _wormholeSetup() public {
        wormhole = IWormhole(address(new MockWormhole(WORMHOLE_HUB_CHAIN_ID, hubChainId)));
    }

    function _deployMachine(address _accountingToken, bytes32 _allowedInstrMerkleRoot, address _flashLoanModule)
        public
        returns (Machine, Caliber)
    {
        vm.prank(dao);
        Machine _machine = Machine(
            machineFactory.createMachine(
                IMachine.MachineInitParams({
                    accountingToken: _accountingToken,
                    initialDepositor: machineDepositor,
                    initialRedeemer: machineRedeemer,
                    initialFeeManager: address(feeManager),
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialMaxFeeAccrualRate: DEFAULT_MACHINE_MAX_FEE_ACCRUAL_RATE,
                    initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT
                }),
                ICaliber.CaliberInitParams({
                    accountingToken: _accountingToken,
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: _allowedInstrMerkleRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialFlashLoanModule: _flashLoanModule
                }),
                IMakinaGovernable.MakinaGovernableInitParams({
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialRiskManager: riskManager,
                    initialRiskManagerTimelock: riskManagerTimelock,
                    initialAuthority: address(accessManager)
                }),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );
        Caliber _caliber = Caliber(_machine.hubCaliber());
        return (_machine, _caliber);
    }
}

abstract contract Base_Spoke_Test is Base_Test {
    SpokeRegistry public spokeRegistry;
    CaliberFactory public caliberFactory;
    UpgradeableBeacon public caliberMailboxBeacon;

    function setUp() public virtual override {
        Base_Test.setUp();
        hubChainId = ChainsInfo.CHAIN_ID_ETHEREUM;

        SpokeCore memory deployment = deploySpokeCore(deployer, dao, hubChainId);
        accessManager = deployment.accessManager;
        oracleRegistry = deployment.oracleRegistry;
        tokenRegistry = deployment.tokenRegistry;
        swapModule = deployment.swapModule;
        spokeRegistry = deployment.spokeRegistry;
        caliberFactory = deployment.caliberFactory;
        caliberBeacon = deployment.caliberBeacon;
        caliberMailboxBeacon = deployment.caliberMailboxBeacon;

        setupSpokeRegistry(deployment);
        setupAccessManager(accessManager, dao);
    }

    function _deployCaliber(
        address _hubMachine,
        address _accountingToken,
        bytes32 _allowedInstrMerkleRoot,
        address _flashLoanModule
    ) public returns (Caliber, CaliberMailbox) {
        vm.prank(dao);
        Caliber _caliber = Caliber(
            caliberFactory.createCaliber(
                ICaliber.CaliberInitParams({
                    accountingToken: _accountingToken,
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: _allowedInstrMerkleRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialFlashLoanModule: _flashLoanModule
                }),
                IMakinaGovernable.MakinaGovernableInitParams({
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialRiskManager: riskManager,
                    initialRiskManagerTimelock: riskManagerTimelock,
                    initialAuthority: address(accessManager)
                }),
                _hubMachine
            )
        );
        CaliberMailbox _mailbox = CaliberMailbox(_caliber.hubMachineEndpoint());
        return (_caliber, _mailbox);
    }
}

abstract contract Base_CrossChain_Test is Base_Hub_Test, Base_Spoke_Test {
    function setUp() public virtual override(Base_Hub_Test, Base_Spoke_Test) {
        Base_Test.setUp();
        Base_Hub_Test.setUp();

        spokeRegistry = _deploySpokeRegistry(
            dao, address(oracleRegistry), address(tokenRegistry), address(swapModule), address(accessManager)
        );

        caliberFactory = _deployCaliberFactory(dao, address(spokeRegistry), address(accessManager));

        caliberMailboxBeacon = _deployCaliberMailboxBeacon(dao, address(spokeRegistry), hubChainId);

        vm.startPrank(dao);
        setupSpokeRegistry(
            SpokeCore({
                accessManager: accessManager,
                oracleRegistry: oracleRegistry,
                swapModule: swapModule,
                spokeRegistry: spokeRegistry,
                tokenRegistry: tokenRegistry,
                caliberBeacon: caliberBeacon,
                caliberFactory: caliberFactory,
                caliberMailboxBeacon: caliberMailboxBeacon
            })
        );
        vm.stopPrank();
    }
}
