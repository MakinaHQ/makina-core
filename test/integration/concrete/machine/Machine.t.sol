// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {MockPool} from "test/mocks/MockPool.sol";

import {Base_Test} from "test/BaseTest.sol";

contract Machine_Integration_Concrete_Test is Base_Test {
    /// @dev A is the accounting token, B is the base token
    /// and E is the reference currency of the oracle registry
    uint256 internal constant PRICE_A_E = 150;
    uint256 internal constant PRICE_B_E = 60000;
    uint256 internal constant PRICE_B_A = 400;

    uint256 internal constant BASE_TOKEN_POS_ID = 2;
    uint256 internal constant VAULT_POS_ID = 3;
    uint256 internal constant POOL_POS_ID = 4;

    MockERC20 internal baseToken;
    MockERC4626 internal vault;
    MockPool internal pool;

    MockPriceFeed internal bPriceFeed1;
    MockPriceFeed internal aPriceFeed1;

    function _setUp() public virtual override {
        baseToken = new MockERC20("baseToken", "BT", 18);
        vault = new MockERC4626("vault", "VLT", IERC20(baseToken), 0);

        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);
        bPriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_E * 1e18), block.timestamp);

        pool = new MockPool(address(accountingToken), address(baseToken), "MockPool", "MP");

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(bPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));
        vm.stopPrank();

        (machine, caliber) = _deployMachine(address(accountingToken), accountingTokenPosId, bytes32(0));

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

    ///
    /// Helper functions
    ///

    modifier whileInRecoveryMode() {
        vm.prank(dao);
        machine.setRecoveryMode(true);
        _;
    }

    modifier withTokenAsBT(address _token, uint256 _posId) {
        vm.prank(dao);
        caliber.addBaseToken(_token, _posId);
        _;
    }
}
