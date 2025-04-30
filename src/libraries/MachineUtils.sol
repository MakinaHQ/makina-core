// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Machine} from "src/machine/Machine.sol";

library MachineUtils {
    using Math for uint256;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    function updateTotalAum(Machine.MachineStorage storage $, address oracleRegistry) external returns (uint256) {
        $._lastTotalAum = _getTotalAum($, oracleRegistry);
        $._lastGlobalAccountingTime = block.timestamp;
        return $._lastTotalAum;
    }

    function manageFees(Machine.MachineStorage storage $) external returns (uint256) {
        uint256 currentTimestamp = block.timestamp;
        uint256 elapsedTime = currentTimestamp - $._lastMintedFeesTime;

        if (elapsedTime >= $._feeMintCooldown) {
            address _feeManager = $._feeManager;
            address _shareToken = $._shareToken;
            uint256 currentShareSupply = IERC20Metadata(_shareToken).totalSupply();

            uint256 fixedFee = IFeeManager(_feeManager).calculateFixedFee(currentShareSupply, elapsedTime);

            // offset fixed fee from the share price performance on which the performance fee is calculated.
            uint256 adjustedSharePrice =
                getSharePrice($._lastTotalAum, currentShareSupply + fixedFee, $._shareTokenDecimalsOffset);
            uint256 perfFee = IFeeManager(_feeManager).calculatePerformanceFee(
                currentShareSupply, $._lastMintedFeesSharePrice, adjustedSharePrice, elapsedTime
            );

            uint256 totalFee = fixedFee + perfFee;
            if (totalFee != 0) {
                uint256 maxFee = $._maxFeeAccrualRate * elapsedTime;
                if (maxFee != 0) {
                    if (totalFee > maxFee) {
                        fixedFee = fixedFee.mulDiv(maxFee, totalFee);
                        perfFee = maxFee - fixedFee;
                        totalFee = maxFee;
                    }
                    uint256 balBefore = IMachineShare(_shareToken).balanceOf(address(this));

                    IMachineShare(_shareToken).mint(address(this), totalFee);
                    IMachineShare(_shareToken).approve(_feeManager, totalFee);

                    IFeeManager(_feeManager).distributeFees(fixedFee, perfFee);

                    IMachineShare(_shareToken).approve(_feeManager, 0);

                    uint256 balAfter = IMachineShare(_shareToken).balanceOf(address(this));
                    if (balAfter > balBefore) {
                        uint256 dust = balAfter - balBefore;
                        IMachineShare(_shareToken).burn(address(this), dust);
                        totalFee -= dust;
                    }
                }
                $._lastMintedFeesTime = currentTimestamp;
                $._lastMintedFeesSharePrice = getSharePrice(
                    $._lastTotalAum, IERC20Metadata(_shareToken).totalSupply(), $._shareTokenDecimalsOffset
                );
            }
            return totalFee;
        }
        return 0;
    }

    /// @dev Manages the migration from a pre-deposit vault to a machine, and initializes the machine's accounting state.
    /// @param $ The machine storage struct.
    /// @param preDepositVault The address of the pre-deposit vault.
    /// @param oracleRegistry The address of the oracle registry.
    function migrateFromPreDeposit(Machine.MachineStorage storage $, address preDepositVault, address oracleRegistry)
        external
    {
        if (
            IPreDepositVault(preDepositVault).shareToken() != $._shareToken
                || IPreDepositVault(preDepositVault).accountingToken() != $._accountingToken
        ) {
            revert IMachine.PreDepositVaultMismatch();
        }
        IPreDepositVault(preDepositVault).migrateToMachine();

        address preDepositToken = IPreDepositVault(preDepositVault).depositToken();
        $._idleTokens.add(preDepositToken);

        $._lastTotalAum = _accountingValueOf(
            oracleRegistry,
            $._accountingToken,
            preDepositToken,
            IERC20Metadata(preDepositToken).balanceOf(address(this))
        );
        $._lastGlobalAccountingTime = block.timestamp;
    }

    /// @dev Calculates the share price based on given AUM, share supply and share token decimals offset.
    function getSharePrice(uint256 aum, uint256 supply, uint256 shareTokenDecimalsOffset)
        public
        pure
        returns (uint256)
    {
        return Constants.SHARE_TOKEN_UNIT.mulDiv(aum + 1, supply + 10 ** shareTokenDecimalsOffset);
    }

    /// @dev Computes the total AUM of the machine.
    /// @param $ The machine storage struct.
    /// @param oracleRegistry The address of the oracle registry.
    function _getTotalAum(Machine.MachineStorage storage $, address oracleRegistry) private view returns (uint256) {
        uint256 totalAum;

        // spoke calibers net AUM
        uint256 currentTimestamp = block.timestamp;
        uint256 len = $._foreignChainIds.length;
        for (uint256 i; i < len;) {
            uint256 chainId = $._foreignChainIds[i];
            IMachine.SpokeCaliberData storage spokeCaliberData = $._spokeCalibersData[chainId];
            if (
                currentTimestamp > spokeCaliberData.timestamp
                    && currentTimestamp - spokeCaliberData.timestamp >= $._caliberStaleThreshold
            ) {
                revert IMachine.CaliberAccountingStale(chainId);
            }
            totalAum += spokeCaliberData.netAum;

            // check for funds received by machine but not declared by spoke caliber
            _checkBridgeState(spokeCaliberData.machineBridgesIn, spokeCaliberData.caliberBridgesOut);

            // check for funds received by spoke caliber but not declared by machine
            _checkBridgeState(spokeCaliberData.caliberBridgesIn, spokeCaliberData.machineBridgesOut);

            // check for funds sent by machine but not yet received by spoke caliber
            uint256 len2 = spokeCaliberData.machineBridgesOut.length();
            for (uint256 j; j < len2;) {
                (address token, uint256 mOut) = spokeCaliberData.machineBridgesOut.at(j);
                (, uint256 cIn) = spokeCaliberData.caliberBridgesIn.tryGet(token);
                if (mOut > cIn) {
                    totalAum += _accountingValueOf(oracleRegistry, $._accountingToken, token, mOut - cIn);
                }
                unchecked {
                    ++j;
                }
            }

            // check for funds sent by spoke caliber but not yet received by machine
            len2 = spokeCaliberData.caliberBridgesOut.length();
            for (uint256 j; j < len2;) {
                (address token, uint256 cOut) = spokeCaliberData.caliberBridgesOut.at(j);
                (, uint256 mIn) = spokeCaliberData.machineBridgesIn.tryGet(token);
                if (cOut > mIn) {
                    totalAum += _accountingValueOf(oracleRegistry, $._accountingToken, token, cOut - mIn);
                }
                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        // hub caliber net AUM
        (uint256 hcAum,,) = ICaliber($._hubCaliber).getDetailedAum();
        totalAum += hcAum;

        // idle tokens
        len = $._idleTokens.length();
        for (uint256 i; i < len;) {
            address token = $._idleTokens.at(i);
            totalAum += _accountingValueOf(
                oracleRegistry, $._accountingToken, token, IERC20Metadata(token).balanceOf(address(this))
            );
            unchecked {
                ++i;
            }
        }

        return totalAum;
    }

    /// @dev Checks if the bridge state is consistent between the machine and spoke caliber.
    function _checkBridgeState(
        EnumerableMap.AddressToUintMap storage insMap,
        EnumerableMap.AddressToUintMap storage outsMap
    ) private view {
        uint256 len = insMap.length();
        for (uint256 i; i < len;) {
            (address token, uint256 amountIn) = insMap.at(i);
            (, uint256 amountOut) = outsMap.tryGet(token);
            if (amountIn > amountOut) {
                revert IMachine.BridgeStateMismatch();
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Computes the accounting value of a given token amount.
    function _accountingValueOf(address oracleRegistry, address accountingToken, address token, uint256 amount)
        private
        view
        returns (uint256)
    {
        if (token == accountingToken) {
            return amount;
        }
        uint256 price = IOracleRegistry(oracleRegistry).getPrice(token, accountingToken);
        return amount.mulDiv(price, (10 ** IERC20Metadata(token).decimals()));
    }
}
