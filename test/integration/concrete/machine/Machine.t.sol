// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Integration_Concrete_Test} from "../IntegrationConcrete.t.sol";

contract Machine_Integration_Concrete_Test is Integration_Concrete_Test {
    function setUp() public virtual override {
        Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(bPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        (machine, caliber) = _deployMachine(address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));
    }

    ///
    /// Helper functions
    ///

    modifier whileInRecoveryMode() {
        vm.prank(dao);
        machine.setRecoveryMode(true);
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
}
