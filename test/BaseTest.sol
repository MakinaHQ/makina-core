// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Base.sol";
import {ICaliberFactory} from "../src/interfaces/ICaliberFactory.sol";
import {ICaliberMailbox} from "../src/interfaces/ICaliberMailbox.sol";
import {IMachine} from "../src/interfaces/IMachine.sol";
import {Caliber} from "../src/caliber/Caliber.sol";
import {HubDualMailbox} from "../src/mailbox/HubDualMailbox.sol";
import {MockWormhole} from "./mocks/MockWormhole.sol";

abstract contract Base_Test is Base {
    /// @dev set MAINNET_RPC_URL in .env to run mainnet tests
    // string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    uint256 public constant DEFAULT_PF_STALE_THRSHLD = 2 hours;

    string public constant DEFAULT_MACHINE_SHARE_TOKEN_NAME = "Machine Share";
    string public constant DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL = "MS";
    uint256 public constant DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD = 30 minutes;
    uint256 public constant DEFAULT_MACHINE_SHARE_LIMIT = type(uint256).max;

    uint256 public constant DEFAULT_CALIBER_POS_STALE_THRESHOLD = 20 minutes;
    uint256 public constant DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK = 1 hours;
    uint256 public constant DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS = 100;
    uint256 public constant DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS = 1000;
    uint256 public constant DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS = 200;

    uint256 public constant HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID = 1;
    uint256 public constant HUB_CALIBER_BASE_TOKEN_1_POS_ID = 2;

    uint256 public constant SPOKE_CALIBER_ACCOUNTING_TOKEN_POS_ID = 1001;
    uint256 public constant SPOKE_CALIBER_BASE_TOKEN_1_POS_ID = 1002;

    uint16 public constant WORMHOLE_HUB_CHAIN_ID = 2;

    address public machineDepositor = makeAddr("MachineDepositor");

    function setUp() public virtual {
        deployer = address(this);
        hubChainId = block.chainid;
        _makinaGovernanceTestSetup();
    }

    /// @dev Should follow _coreSharedSetup() when used.
    function _hubSetup() public {
        _wormholeSetup();
        _coreHubSetup();
        _hubRegistrySetup();
        _accessManagerTestSetup();
    }

    /// @dev Should follow _coreSharedSetup() when used.
    function _spokeSetup() public {
        _coreSpokeSetup();
        _spokeRegistrySetup();
        _accessManagerTestSetup();
    }

    function _makinaGovernanceTestSetup() public {
        dao = makeAddr("MakinaDAO");
        mechanic = makeAddr("Mechanic");
        securityCouncil = makeAddr("SecurityCouncil");
    }

    function _wormholeSetup() public {
        wormhole = IWormhole(address(new MockWormhole(WORMHOLE_HUB_CHAIN_ID, hubChainId)));
    }

    function _accessManagerTestSetup() public {
        accessManager.grantRole(accessManager.ADMIN_ROLE(), dao, 0);
        accessManager.revokeRole(accessManager.ADMIN_ROLE(), address(this));
    }

    function _deployMachine(address _accountingToken, uint256 _accountingTokenPosId, bytes32 allowedInstrMerkleRoot)
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
                    depositor: machineDepositor,
                    initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    hubCaliberAccountingTokenPosID: _accountingTokenPosId,
                    hubCaliberPosStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    hubCaliberAllowedInstrRoot: allowedInstrMerkleRoot,
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
        Caliber _caliber = Caliber(ICaliberMailbox(_machine.hubCaliberMailbox()).caliber());
        HubDualMailbox _mailbox = HubDualMailbox(_machine.hubCaliberMailbox());
        return (_machine, _caliber, _mailbox);
    }

    function _deployCaliber(
        address _hubMachineEndpoint,
        address _accountingToken,
        uint256 _accountingTokenPosId,
        bytes32 allowedInstrMerkleRoot
    ) public returns (Caliber, SpokeCaliberMailbox) {
        vm.prank(dao);
        Caliber _caliber = Caliber(
            spokeCaliberFactory.deployCaliber(
                ICaliberFactory.CaliberDeployParams({
                    hubMachineEndpoint: _hubMachineEndpoint,
                    accountingToken: _accountingToken,
                    accountingTokenPosId: _accountingTokenPosId,
                    initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                    initialAllowedInstrRoot: allowedInstrMerkleRoot,
                    initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                    initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                    initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                    initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                    initialMechanic: mechanic,
                    initialSecurityCouncil: securityCouncil,
                    initialAuthority: address(accessManager)
                })
            )
        );
        SpokeCaliberMailbox _mailbox = SpokeCaliberMailbox(_caliber.mailbox());
        return (_caliber, _mailbox);
    }

    function _generateMerkleData(
        address _caliber,
        address _mockAccountingToken,
        address _mockBaseToken,
        address _mockVault,
        uint256 _mockVaultPosId,
        address _mockSupplyModule,
        uint256 _mockSupplyModulePosId,
        address _mockBorrowModule,
        uint256 _mockBorrowModulePosId,
        address _mockPool,
        uint256 _mockPoolPosId
    ) internal {
        string[] memory command = new string[](13);
        command[0] = "yarn";
        command[1] = "genMerkleDataMock";
        command[2] = vm.toString(_caliber);
        command[3] = vm.toString(_mockAccountingToken);
        command[4] = vm.toString(_mockBaseToken);
        command[5] = vm.toString(_mockVault);
        command[6] = vm.toString(_mockVaultPosId);
        command[7] = vm.toString(_mockSupplyModule);
        command[8] = vm.toString(_mockSupplyModulePosId);
        command[9] = vm.toString(_mockBorrowModule);
        command[10] = vm.toString(_mockBorrowModulePosId);
        command[11] = vm.toString(_mockPool);
        command[12] = vm.toString(_mockPoolPosId);
        vm.ffi(command);
    }
}
