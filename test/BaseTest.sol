// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Base.sol";
import {Caliber} from "../src/caliber/Caliber.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

abstract contract Base_Test is Base {
    /// @dev set MAINNET_RPC_URL in .env to run mainnet tests
    // string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    bytes32 public constant MOCK_TOKENS_SALT = bytes32("0x123");

    uint256 public constant DEFAULT_PF_STALE_THRSHLD = 2 hours;

    uint256 public constant DEFAULT_CALIBER_POS_STALE_THRESHOLD = 20 minutes;

    uint256 public constant DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK = 1 hours;

    uint256 public constant DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS = 100;

    uint256 public constant DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS = 200;

    TestMode public mode = TestMode.CONCRETE;

    MockERC20 public accountingToken;
    uint256 public accountingTokenPosId;
    Caliber public caliber;

    enum TestMode {
        CONCRETE,
        FUZZ,
        CUSTOM
    }

    function setUp() public {
        // vm.selectFork(vm.createFork(MAINNET_RPC_URL));

        deployer = address(this);

        if (mode == TestMode.CONCRETE) {
            _testSetupMakinaGovernance();
            _coreSetup();
            _testSetupRegistry();
            _testSetupAccessManager();
            _testSetupTokens();
            _setUp();
        } else if (mode == TestMode.FUZZ) {
            _testSetupMakinaGovernance();
            _coreSetup();
            _testSetupRegistry();
            _testSetupAccessManager();
        } else if (mode == TestMode.CUSTOM) {
            _setUp();
        }
    }

    /// @dev Can be overriden to provide additional configuration
    function _setUp() public virtual {}

    function _testSetupMakinaGovernance() public {
        dao = makeAddr("MakinaDAO");
        mechanic = makeAddr("Mechanic");
        securityCouncil = makeAddr("SecurityCouncil");
    }

    function _testSetupTokens() public {
        accountingToken = new MockERC20("accountingToken", "ACT", 18);
        accountingTokenPosId = 1;
    }

    function _testSetupRegistry() public {
        hubRegistry.setCaliberBeacon(address(caliberBeacon));
        hubRegistry.setHubDualMailboxBeacon(address(hubDualMailboxBeacon));
        hubRegistry.setCaliberFactory(address(caliberFactory));
        hubRegistry.setMachineBeacon(makeAddr("machineBeacon"));
        hubRegistry.setMachineFactory(makeAddr("machineFactory"));
    }

    function _testSetupAccessManager() public {
        accessManager.grantRole(accessManager.ADMIN_ROLE(), dao, 0);
        accessManager.revokeRole(accessManager.ADMIN_ROLE(), address(this));
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
                _hubMachineEndpoint,
                _accountingToken,
                _accountingTokenPosId,
                DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                allowedInstrMerkleRoot,
                DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS,
                DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                mechanic,
                securityCouncil,
                address(accessManager)
            )
        );
    }

    function _generateMerkleData(
        address _caliber,
        address _mockAccountingToken,
        address _mockBaseToken,
        address _mockVault,
        uint256 _mockVaultPosId,
        address _mockPool,
        uint256 _mockPoolPosId
    ) internal {
        string[] memory command = new string[](9);
        command[0] = "yarn";
        command[1] = "genMerkleDataMock";
        command[2] = vm.toString(_caliber);
        command[3] = vm.toString(_mockAccountingToken);
        command[4] = vm.toString(_mockBaseToken);
        command[5] = vm.toString(_mockVault);
        command[6] = vm.toString(_mockVaultPosId);
        command[7] = vm.toString(_mockPool);
        command[8] = vm.toString(_mockPoolPosId);
        vm.ffi(command);
    }
}
