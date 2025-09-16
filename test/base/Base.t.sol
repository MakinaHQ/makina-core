// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";

import {Caliber} from "../../src/caliber/Caliber.sol";
import {SpokeCoreFactory} from "../../src/factories/SpokeCoreFactory.sol";
import {CaliberMailbox} from "../../src/caliber/CaliberMailbox.sol";
import {ChainRegistry} from "../../src/registries/ChainRegistry.sol";
import {ChainsInfo} from "../utils/ChainsInfo.sol";
import {Constants} from "../utils/Constants.sol";
import {HubCoreRegistry} from "../../src/registries/HubCoreRegistry.sol";
import {ICaliber} from "../../src/interfaces/ICaliber.sol";
import {IMachine} from "../../src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "../../src/interfaces/IMakinaGovernable.sol";
import {Machine} from "../../src/machine/Machine.sol";
import {HubCoreFactory} from "../../src/factories/HubCoreFactory.sol";
import {MockFeeManager} from "../mocks/MockFeeManager.sol";
import {MockWormhole} from "../mocks/MockWormhole.sol";
import {OracleRegistry} from "../../src/registries/OracleRegistry.sol";
import {SpokeCoreRegistry} from "../../src/registries/SpokeCoreRegistry.sol";
import {SwapModule} from "../../src/swap/SwapModule.sol";
import {TokenRegistry} from "../../src/registries/TokenRegistry.sol";

import {Base} from "./Base.sol";

abstract contract Base_Test is Base, Constants, Test {
    address public deployer;

    uint256 public hubChainId;

    address public dao;
    address public mechanic;
    address public securityCouncil;
    address public riskManager;
    address public riskManagerTimelock;

    AccessManagerUpgradeable public accessManager;
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
    HubCoreRegistry public hubCoreRegistry;
    ChainRegistry public chainRegistry;
    HubCoreFactory public hubCoreFactory;
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
        hubCoreRegistry = deployment.hubCoreRegistry;
        tokenRegistry = deployment.tokenRegistry;
        chainRegistry = deployment.chainRegistry;
        hubCoreFactory = deployment.hubCoreFactory;
        caliberBeacon = deployment.caliberBeacon;
        machineBeacon = deployment.machineBeacon;
        preDepositVaultBeacon = deployment.preDepositVaultBeacon;

        setupHubCoreRegistry(deployment);
        setupHubCoreAMFunctionRoles(deployment);
        setupAccessManagerRoles(accessManager, dao, dao, dao, dao, dao, deployer);
    }

    function _wormholeSetup() public {
        wormhole = IWormhole(address(new MockWormhole(WORMHOLE_HUB_CHAIN_ID, hubChainId)));
    }

    function _deployMachine(address _accountingToken, bytes32 _allowedInstrMerkleRoot, bytes32 _salt)
        public
        returns (Machine, Caliber)
    {
        vm.prank(dao);
        Machine _machine = Machine(
            hubCoreFactory.createMachine(
                IMachine.MachineInitParams({
                    initialDepositor: machineDepositor,
                    initialRedeemer: machineRedeemer,
                    initialFeeManager: address(feeManager),
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialMaxFixedFeeAccrualRate: DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE,
                    initialMaxPerfFeeAccrualRate: DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE,
                    initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT
                }),
                ICaliber.CaliberInitParams({
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: _allowedInstrMerkleRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION
                }),
                IMakinaGovernable.MakinaGovernableInitParams({
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialRiskManager: riskManager,
                    initialRiskManagerTimelock: riskManagerTimelock,
                    initialAuthority: address(accessManager)
                }),
                _accountingToken,
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL,
                _salt
            )
        );
        Caliber _caliber = Caliber(_machine.hubCaliber());
        return (_machine, _caliber);
    }
}

abstract contract Base_Spoke_Test is Base_Test {
    SpokeCoreRegistry public spokeCoreRegistry;
    SpokeCoreFactory public spokeCoreFactory;
    UpgradeableBeacon public caliberMailboxBeacon;

    function setUp() public virtual override {
        Base_Test.setUp();
        hubChainId = ChainsInfo.CHAIN_ID_ETHEREUM;

        SpokeCore memory deployment = deploySpokeCore(deployer, dao, hubChainId);
        accessManager = deployment.accessManager;
        oracleRegistry = deployment.oracleRegistry;
        tokenRegistry = deployment.tokenRegistry;
        swapModule = deployment.swapModule;
        spokeCoreRegistry = deployment.spokeCoreRegistry;
        spokeCoreFactory = deployment.spokeCoreFactory;
        caliberBeacon = deployment.caliberBeacon;
        caliberMailboxBeacon = deployment.caliberMailboxBeacon;

        setupSpokeCoreRegistry(deployment);
        setupSpokeCoreAMFunctionRoles(deployment);
        setupAccessManagerRoles(accessManager, dao, dao, dao, dao, dao, deployer);
    }

    function _deployCaliber(
        address _hubMachine,
        address _accountingToken,
        bytes32 _allowedInstrMerkleRoot,
        bytes32 _salt
    ) public returns (Caliber, CaliberMailbox) {
        vm.prank(dao);
        Caliber _caliber = Caliber(
            spokeCoreFactory.createCaliber(
                ICaliber.CaliberInitParams({
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: _allowedInstrMerkleRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION
                }),
                IMakinaGovernable.MakinaGovernableInitParams({
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialRiskManager: riskManager,
                    initialRiskManagerTimelock: riskManagerTimelock,
                    initialAuthority: address(accessManager)
                }),
                _accountingToken,
                _hubMachine,
                _salt
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

        spokeCoreRegistry =
            _deploySpokeCoreRegistry(dao, address(oracleRegistry), address(tokenRegistry), address(accessManager));

        spokeCoreFactory = _deploySpokeCoreFactory(dao, address(spokeCoreRegistry), address(accessManager));

        caliberMailboxBeacon = _deployCaliberMailboxBeacon(dao, address(spokeCoreRegistry), hubChainId);

        vm.startPrank(dao);
        setupSpokeCoreRegistry(
            SpokeCore({
                accessManager: accessManager,
                oracleRegistry: oracleRegistry,
                swapModule: swapModule,
                spokeCoreRegistry: spokeCoreRegistry,
                tokenRegistry: tokenRegistry,
                caliberBeacon: caliberBeacon,
                spokeCoreFactory: spokeCoreFactory,
                caliberMailboxBeacon: caliberMailboxBeacon
            })
        );
        vm.stopPrank();
    }
}
