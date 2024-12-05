// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/StdJson.sol";
import "./Base.sol";
import {Caliber} from "../src/caliber/Caliber.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

abstract contract BaseTest is Base {
    using stdJson for string;

    /// @dev set MAINNET_RPC_URL in .env to run mainnet tests
    // string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    bytes32 public constant MOCK_TOKENS_SALT = bytes32("0x123");

    uint256 public constant DEFAULT_PF_STALE_THRSHLD = 2 hours;

    uint256 public constant DEFAULT_CALIBER_POS_STALE_THRESHOLD = 20 minutes;

    uint256 public constant DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK = 1 hours;

    uint256 public constant DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS = 200;

    string public allowedInstrMerkleData;

    TestMode public mode = TestMode.UNIT;

    MockERC20 accountingToken;
    uint256 accountingTokenPosID;
    Caliber caliber;

    enum TestMode {
        UNIT,
        FUZZ
    }

    function setUp() public {
        // vm.selectFork(vm.createFork(MAINNET_RPC_URL));

        if (mode == TestMode.UNIT) {
            _testSetupMakinaGovernance();
            _coreSetup();
            _testSetupRegistry();
            _testSetupTokens();
            _setUp();
        } else if (mode == TestMode.FUZZ) {
            _testSetupMakinaGovernance();
            _coreSetup();
            _testSetupRegistry();
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
        accountingTokenPosID = 1;
    }

    function _testSetupRegistry() public {
        vm.startPrank(dao);
        hubRegistry.setCaliberBeacon(address(caliberBeacon));
        hubRegistry.setCaliberInboxBeacon(address(caliberInboxBeacon));
        hubRegistry.setCaliberFactory(address(caliberFactory));
        hubRegistry.setMachineBeacon(makeAddr("machineBeacon"));
        hubRegistry.setMachineHubInboxBeacon(makeAddr("machineHubInboxBeacon"));
        hubRegistry.setMachineFactory(makeAddr("machineFactory"));
        vm.stopPrank();
    }

    function _deployCaliber(
        address _hubMachineInbox,
        address _accountingToken,
        uint256 _accountingTokenPosID,
        bytes32 allowedInstrMerkleRoot
    ) public returns (Caliber) {
        vm.prank(dao);
        return Caliber(
            caliberFactory.deployCaliber(
                _hubMachineInbox,
                _accountingToken,
                _accountingTokenPosID,
                DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                allowedInstrMerkleRoot,
                DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                mechanic,
                securityCouncil
            )
        );
    }

    function _generateMerkleData(address _caliber, address _mockBaseToken, address _mockVault, uint256 _mockVaultPosId)
        internal
    {
        string[] memory command = new string[](6);
        command[0] = "yarn";
        command[1] = "genMerkleData";
        command[2] = vm.toString(_caliber);
        command[3] = vm.toString(_mockBaseToken);
        command[4] = vm.toString(_mockVault);
        command[5] = vm.toString(_mockVaultPosId);
        vm.ffi(command);
        allowedInstrMerkleData = _getMerkleData();
    }

    function _getMerkleData() internal view returns (string memory) {
        return vm.readFile(string.concat(vm.projectRoot(), "/script/merkle/merkleTreeData.json"));
    }

    function _getAllowedInstrMerkleRoot() internal view returns (bytes32) {
        return allowedInstrMerkleData.readBytes32(".root");
    }

    function _getDeposit4626InstrProof() internal view returns (bytes32[] memory) {
        return allowedInstrMerkleData.readBytes32Array(".proofDepositMock4626");
    }

    function _getRedeem4626InstrProof() internal view returns (bytes32[] memory) {
        return allowedInstrMerkleData.readBytes32Array(".proofRedeemMock4626");
    }

    function _getAccounting4626InstrProof() internal view returns (bytes32[] memory) {
        return allowedInstrMerkleData.readBytes32Array(".proofAccountingMock4626");
    }
}
