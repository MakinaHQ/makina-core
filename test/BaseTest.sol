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

    address public mockTokensDeployer;

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
            _testSetupBefore();
            _coreSetup();
            _testSetupAfter();
            _setUp();
        } else if (mode == TestMode.FUZZ) {
            _testSetupBefore();
            _coreSetup();
        }
    }

    /// @dev Can be overriden to provide additional configuration
    function _setUp() public virtual {}

    function _testSetupBefore() public {
        dao = makeAddr("MakinaDAO");
        mechanic = makeAddr("Mechanic");
        securityCouncil = makeAddr("SecurityCouncil");
    }

    function _testSetupAfter() public {
        mockTokensDeployer = makeAddr("MOCK_TOKENS_DEPLOYER");
        accountingToken = new MockERC20("accountingToken", "ACT", 18);
        accountingTokenPosID = 1;
    }

    function _deployCaliber(address _accountingToken, uint256 _accountingTokenPosID, bytes32 allowedInstrMerkleRoot)
        public
        returns (Caliber)
    {
        return Caliber(
            address(
                new TransparentUpgradeableProxy(
                    address(new Caliber()),
                    address(this),
                    abi.encodeWithSelector(
                        Caliber(address(0)).initialize.selector,
                        address(0),
                        _accountingToken,
                        _accountingTokenPosID,
                        address(oracleRegistry),
                        allowedInstrMerkleRoot,
                        mechanic,
                        securityCouncil,
                        accessManager
                    )
                )
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
