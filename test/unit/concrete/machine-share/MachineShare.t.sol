// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {Constants} from "src/libraries/Constants.sol";

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract MachineShare_Unit_Concrete_Test is Unit_Concrete_Test {
    IMachineShare internal shareToken;

    function setUp() public override {
        Unit_Concrete_Test.setUp();

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine, caliber) = _deployMachine(address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));
        shareToken = IMachineShare(machine.shareToken());
    }

    function test_hubDualMailbox_getters() public view {
        assertEq(shareToken.machine(), address(machine));
        assertEq(shareToken.name(), DEFAULT_MACHINE_SHARE_TOKEN_NAME);
        assertEq(shareToken.symbol(), DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL);
        assertEq(shareToken.decimals(), Constants.SHARE_TOKEN_DECIMALS);
    }
}
