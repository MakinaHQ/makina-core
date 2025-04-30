// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {Machine} from "src/machine/Machine.sol";

library MachineUtils {
    using Math for uint256;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Computes the total AUM of the machine.
    function _getTotalAum(Machine.MachineStorage storage $, address oracleRegistry) external view returns (uint256) {
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
