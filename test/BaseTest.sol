// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Base.sol";
import {ICaliberFactory} from "../src/interfaces/ICaliberFactory.sol";
import {ICaliberMailbox} from "../src/interfaces/ICaliberMailbox.sol";
import {IMachine} from "../src/interfaces/IMachine.sol";
import {Caliber} from "../src/caliber/Caliber.sol";
import {HubDualMailbox} from "../src/mailbox/HubDualMailbox.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

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

    MockERC20 public accountingToken;
    MockERC20 public baseToken;

    Machine public machine;
    Caliber public caliber;
    HubDualMailbox public hubDualMailbox;

    address public machineDepositor = makeAddr("MachineDepositor");

    function setUp() public virtual {
        deployer = address(this);

        _testSetupMakinaGovernance();
        _coreSetup();
        _testSetupRegistry();
        _testSetupAccessManager();
    }

    function _testSetupMakinaGovernance() public {
        dao = makeAddr("MakinaDAO");
        mechanic = makeAddr("Mechanic");
        securityCouncil = makeAddr("SecurityCouncil");
    }

    function _testSetupRegistry() public {
        hubRegistry.setCaliberBeacon(address(caliberBeacon));
        hubRegistry.setCaliberFactory(address(caliberFactory));
        hubRegistry.setMachineBeacon(address(machineBeacon));
        hubRegistry.setMachineFactory(address(machineFactory));
        hubRegistry.setHubDualMailboxBeacon(address(hubDualMailboxBeacon));
    }

    function _testSetupAccessManager() public {
        accessManager.grantRole(accessManager.ADMIN_ROLE(), dao, 0);
        accessManager.revokeRole(accessManager.ADMIN_ROLE(), address(this));
    }

    function _deployMockTokens() public {
        accountingToken = new MockERC20("accountingToken", "ACT", 18);
        baseToken = new MockERC20("baseToken", "BT", 18);
    }

    function _deployMachine(address _accountingToken, uint256 _accountingTokenPosId, bytes32 allowedInstrMerkleRoot)
        public
        returns (Machine, Caliber)
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
        Caliber _caliber = Caliber(ICaliberMailbox(_machine.getMailbox(block.chainid)).caliber());
        return (_machine, _caliber);
    }

    function _deployCaliber(
        address _hubMachineEndpoint,
        address _accountingToken,
        uint256 _accountingTokenPosId,
        bytes32 allowedInstrMerkleRoot
    ) public returns (Caliber) {
        vm.prank(dao);
        return Caliber(
            caliberFactory.deployCaliber(
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
