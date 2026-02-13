// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {MachineShare} from "src/machine/MachineShare.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {DecimalsUtils} from "src/libraries/DecimalsUtils.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";

import {Base_Hub_Test} from "test/base/Base.t.sol";

contract Previews_Integration_Fuzz_Test is Base_Hub_Test {
    MockERC20 internal depositToken;
    MockERC20 internal accountingToken;
    MachineShare internal shareToken;

    PreDepositVault internal preDepositVault;

    uint256 internal depositTokenUnit;
    uint256 internal accountingTokenUnit;
    uint256 internal constant shareTokenUnit = 10 ** DecimalsUtils.SHARE_TOKEN_DECIMALS;

    struct Data {
        uint8 dtDecimals;
        uint8 atDecimals;
        uint8 dfDecimals;
        uint8 afDecimals;
        uint32 price_d_e;
        uint32 price_a_e;
    }

    function _fuzzTestSetupAfter(Data memory data) public {
        data.dtDecimals = uint8(bound(data.dtDecimals, DecimalsUtils.MIN_DECIMALS, DecimalsUtils.MAX_DECIMALS));
        data.atDecimals = uint8(bound(data.atDecimals, DecimalsUtils.MIN_DECIMALS, DecimalsUtils.MAX_DECIMALS));
        data.dfDecimals = uint8(bound(data.dfDecimals, 6, 18));
        data.afDecimals = uint8(bound(data.afDecimals, 6, 18));
        data.price_a_e = uint32(bound(data.price_a_e, 1, 1e4));
        data.price_d_e = uint32(bound(data.price_d_e, 1 + data.price_a_e / 5, data.price_a_e * 5));

        depositToken = new MockERC20("Deposit Token", "DT", data.dtDecimals);
        depositTokenUnit = 10 ** depositToken.decimals();

        accountingToken = new MockERC20("Accounting Token", "ACT", data.atDecimals);
        accountingTokenUnit = 10 ** accountingToken.decimals();

        MockPriceFeed dPriceFeed1 =
            new MockPriceFeed(data.dfDecimals, int256(data.price_d_e * (10 ** data.dfDecimals)), block.timestamp);
        MockPriceFeed aPriceFeed1 =
            new MockPriceFeed(data.afDecimals, int256(data.price_a_e * (10 ** data.afDecimals)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setFeedRoute(
            address(depositToken), address(dPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setFeedRoute(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        vm.prank(dao);
        preDepositVault = PreDepositVault(
            hubCoreFactory.createPreDepositVault(
                IPreDepositVault.PreDepositVaultInitParams({
                    initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                    initialWhitelistMode: false,
                    initialRiskManager: address(0),
                    initialAuthority: address(accessManager)
                }),
                address(depositToken),
                address(accountingToken),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL
            )
        );
        shareToken = MachineShare(preDepositVault.shareToken());
    }

    function testFuzz_Previews(Data memory data, uint256[10] memory amounts, bool[10] memory direction) public {
        _fuzzTestSetupAfter(data);

        assertEq(
            preDepositVault.previewDeposit(depositTokenUnit),
            shareTokenUnit * (accountingTokenUnit * data.price_d_e / data.price_a_e) / accountingTokenUnit
        );
        assertEq(
            preDepositVault.previewRedeem(shareTokenUnit),
            depositTokenUnit * accountingTokenUnit / (accountingTokenUnit * data.price_d_e / data.price_a_e)
        );

        for (uint256 i; i < amounts.length; i++) {
            if (direction[i]) {
                uint256 assets = bound(amounts[i], depositTokenUnit / 1e3, 1e30);
                deal(address(depositToken), address(this), assets, true);

                // deposit assets into the preDepositVault
                depositToken.approve(address(preDepositVault), assets);
                preDepositVault.deposit(assets, address(this), 0, 0);
            } else {
                uint256 maxRedeem = shareToken.balanceOf(address(this));
                if (maxRedeem == 0) {
                    continue;
                }
                uint256 sharesToRedeem = bound(amounts[i], 1, maxRedeem);

                // avoid low liquidity cases
                uint256 minLiquidity = depositTokenUnit / 100;
                if (
                    preDepositVault.totalAssets() < minLiquidity
                        || preDepositVault.totalAssets() - minLiquidity < preDepositVault.previewRedeem(sharesToRedeem)
                ) {
                    continue;
                }

                // redeem shares from the preDepositVault
                preDepositVault.redeem(sharesToRedeem, address(this), 0);
            }

            assertApproxEqRel(
                preDepositVault.previewDeposit(depositTokenUnit),
                shareTokenUnit * (accountingTokenUnit * data.price_d_e / data.price_a_e) / accountingTokenUnit,
                1e15
            );
            assertApproxEqRel(
                preDepositVault.previewRedeem(shareTokenUnit),
                depositTokenUnit * accountingTokenUnit / (accountingTokenUnit * data.price_d_e / data.price_a_e),
                1e15
            );
        }
    }
}
