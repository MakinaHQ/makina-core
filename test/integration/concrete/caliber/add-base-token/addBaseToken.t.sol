// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract AddBaseToken_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(IMakinaGovernable.UnauthorizedCaller.selector);
        caliber.addBaseToken(address(baseToken));
    }

    function test_RevertWhen_AlreadyExistingBaseToken() public withTokenAsBT(address(baseToken)) {
        vm.expectRevert(ICaliber.BaseTokenAlreadyExists.selector);
        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(baseToken));
    }

    function test_RevertWhen_TokenAddressZero() public {
        vm.expectRevert(ICaliber.ZeroTokenAddress.selector);
        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(0));
    }

    function test_RevertGiven_PriceFeedRouteNotRegistered() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        vm.expectRevert(
            abi.encodeWithSelector(IOracleRegistry.PriceFeedRouteNotRegistered.selector, address(baseToken2))
        );
        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(baseToken2));
    }

    function test_AddBaseToken() public {
        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.BaseTokenAdded(address(baseToken));
        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(baseToken));

        assertEq(caliber.isBaseToken(address(baseToken)), true);
        assertEq(caliber.getBaseTokensLength(), 2);
    }
}
