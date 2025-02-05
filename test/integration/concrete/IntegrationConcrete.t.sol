// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

import {Base_Test} from "test/BaseTest.sol";

abstract contract Integration_Concrete_Test is Base_Test {
    /// @dev A denotes the accounting token, B denotes the base token
    /// and E is the reference currency of the oracle registry.
    uint256 internal constant PRICE_A_E = 150;
    uint256 internal constant PRICE_B_E = 60000;
    uint256 internal constant PRICE_B_A = 400;

    uint256 internal constant VAULT_POS_ID = 3;
    uint256 internal constant POOL_POS_ID = 4;

    MockERC4626 internal vault;
    MockPool internal pool;

    MockPriceFeed internal aPriceFeed1;
    MockPriceFeed internal bPriceFeed1;

    function setUp() public virtual override {
        Base_Test.setUp();
        _deployMockTokens();

        vault = new MockERC4626("vault", "VLT", IERC20(baseToken), 0);
        pool = new MockPool(address(accountingToken), address(baseToken), "MockPool", "MP");

        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);
        bPriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_E * 1e18), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(bPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));
        vm.stopPrank();

        (machine, caliber) = _deployMachine(address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));
    }

    ///
    /// Modifiers
    ///

    modifier whileInRecoveryMode() {
        vm.startPrank(dao);
        machine.setRecoveryMode(true);
        caliber.setRecoveryMode(true);
        vm.stopPrank();
        _;
    }

    modifier whileInDepositorOnlyMode() {
        vm.prank(dao);
        machine.setDepositorOnlyMode(true);
        _;
    }

    modifier withTokenAsBT(address _token, uint256 _posId) {
        vm.prank(dao);
        caliber.addBaseToken(_token, _posId);
        _;
    }

    ///
    /// Helper functions
    ///

    function _setUpCaliberMerkleRoot() internal {
        // generate merkle tree for instructions involving mock base token and vault
        _generateMerkleData(
            address(caliber),
            address(accountingToken),
            address(baseToken),
            address(vault),
            VAULT_POS_ID,
            address(pool),
            POOL_POS_ID
        );

        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(MerkleProofs._getAllowedInstrMerkleRoot());
        skip(caliber.timelockDuration() + 1);
    }

    function _addLiquidityToMockPool(uint256 _amount1, uint256 _amount2) internal {
        deal(address(accountingToken), address(this), _amount1, true);
        deal(address(baseToken), address(this), _amount2, true);
        accountingToken.approve(address(pool), _amount1);
        baseToken.approve(address(pool), _amount2);
        pool.addLiquidity(_amount1, _amount2);
    }
}
