// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {Machine} from "src/machine/Machine.sol";
import {Constants} from "src/libraries/Constants.sol";
import {MachineShare} from "src/machine/MachineShare.sol";

import {Base_Hub_Test} from "test/base/Base.t.sol";

contract Converts_Integration_Fuzz_Test is Base_Hub_Test {
    MockERC20 public accountingToken;
    Machine public machine;
    MachineShare public shareToken;

    uint256 public accountingTokenUnit;
    uint256 public constant shareTokenUnit = 10 ** Constants.SHARE_TOKEN_DECIMALS;

    function _fuzzTestSetupAfter(uint256 atDecimals) public {
        atDecimals =
            uint8(bound(atDecimals, Constants.MIN_ACCOUNTING_TOKEN_DECIMALS, Constants.MAX_ACCOUNTING_TOKEN_DECIMALS));

        accountingToken = new MockERC20("Accounting Token", "ACT", atDecimals);
        accountingTokenUnit = 10 ** accountingToken.decimals();

        MockPriceFeed aPriceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setFeedRoute(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        (machine,) = _deployMachine(address(accountingToken), bytes32(0));
        shareToken = MachineShare(machine.shareToken());
    }

    function testFuzz_Converts(uint256 atDecimals, uint256[10] memory amounts, bool[10] memory direction) public {
        _fuzzTestSetupAfter(atDecimals);

        assertEq(machine.convertToShares(accountingTokenUnit), shareTokenUnit);
        assertEq(machine.convertToAssets(shareTokenUnit), accountingTokenUnit);

        for (uint256 i; i < amounts.length; i++) {
            if (direction[i]) {
                uint256 assets = amounts[i] = bound(amounts[i], 1, 1e40);

                deal(address(accountingToken), machineDepositor, assets, true);

                // deposit assets into the machine
                vm.startPrank(machineDepositor);
                accountingToken.approve(address(machine), assets);
                machine.deposit(assets, machineRedeemer);
                vm.stopPrank();
            } else {
                uint256 maxRedeem = shareToken.balanceOf(machineRedeemer);
                if (maxRedeem == 0) {
                    continue;
                }
                uint256 sharesToRedeem = bound(amounts[i], 1, maxRedeem);

                // avoid low liquidity cases
                if (
                    accountingToken.balanceOf(address(machine)) - machine.convertToAssets(sharesToRedeem)
                        < accountingTokenUnit / 100
                ) {
                    continue;
                }

                // redeem shares from the machine
                vm.prank(machineRedeemer);
                machine.redeem(sharesToRedeem, machineDepositor);
            }

            assertApproxEqRel(machine.convertToShares(accountingTokenUnit), shareTokenUnit, 1e14);
            assertApproxEqRel(machine.convertToAssets(shareTokenUnit), accountingTokenUnit, 1e14);
        }
    }
}
