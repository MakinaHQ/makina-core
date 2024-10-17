// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./Base.sol";
import {Caliber} from "../src/Caliber.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

abstract contract BaseTest is Base {
    /// @dev set MAINNET_RPC_URL in .env to run mainnet tests
    // string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    TestMode public mode = TestMode.UNIT;

    uint256 public constant DEFAULT_PF_STALE_THRSHLD = 2 hours;

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
    }

    function _testSetupAfter() public {
        accountingToken = new MockERC20("AccountingToken", "ACT", 18);
        accountingTokenPosID = 1;
    }

    function _deployCaliber(address _accountingToken, uint256 _accountingTokenPosID) public returns (Caliber) {
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
                        mechanic,
                        accessManager
                    )
                )
            )
        );
    }
}
