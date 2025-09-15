// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PerChainQueryResponse} from "@wormhole/sdk/libraries/QueryResponse.sol";
import {GuardianSignature} from "@wormhole/sdk/libraries/VaaLib.sol";

import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox} from "../interfaces/ICaliberMailbox.sol";
import {IChainRegistry} from "../interfaces/IChainRegistry.sol";
import {IFeeManager} from "../interfaces/IFeeManager.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IMachineShare} from "../interfaces/IMachineShare.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";
import {IPreDepositVault} from "../interfaces/IPreDepositVault.sol";
import {ITokenRegistry} from "../interfaces/ITokenRegistry.sol";
import {CaliberAccountingCCQ} from "./CaliberAccountingCCQ.sol";
import {Errors} from "./Errors.sol";
import {DecimalsUtils} from "./DecimalsUtils.sol";
import {Machine} from "../machine/Machine.sol";

library MachineUtils {
    using Math for uint256;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private constant FEE_ACCRUAL_RATE_DIVISOR = 1e18;

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
            uint256 currentShareSupply = IERC20(_shareToken).totalSupply();

            uint256 fixedFee = Math.min(
                IFeeManager(_feeManager).calculateFixedFee(currentShareSupply, elapsedTime),
                (currentShareSupply * elapsedTime).mulDiv($._maxFixedFeeAccrualRate, FEE_ACCRUAL_RATE_DIVISOR)
            );

            // offset fixed fee from the share price performance on which the performance fee is calculated.
            uint256 netSharePrice =
                getSharePrice($._lastTotalAum, currentShareSupply + fixedFee, $._shareTokenDecimalsOffset);
            uint256 perfFee = Math.min(
                IFeeManager(_feeManager).calculatePerformanceFee(
                    currentShareSupply, $._lastMintedFeesSharePrice, netSharePrice, elapsedTime
                ),
                (currentShareSupply * elapsedTime).mulDiv($._maxPerfFeeAccrualRate, FEE_ACCRUAL_RATE_DIVISOR)
            );

            uint256 totalFee = fixedFee + perfFee;
            if (totalFee != 0) {
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
            $._lastMintedFeesSharePrice =
                getSharePrice($._lastTotalAum, IERC20(_shareToken).totalSupply(), $._shareTokenDecimalsOffset);

            return totalFee;
        }
        return 0;
    }

    /// @dev Updates the spoke caliber accounting data in the machine storage.
    /// @param $ The machine storage struct.
    /// @param tokenRegistry The address of the token registry.
    /// @param chainRegistry The address of the chain registry.
    /// @param wormhole The address of the Core Wormhole contract.
    /// @param response The Wormhole CCQ response payload containing the accounting data.
    /// @param signatures The array of Wormhole guardians signatures attesting to the validity of the response.
    function updateSpokeCaliberAccountingData(
        Machine.MachineStorage storage $,
        address tokenRegistry,
        address chainRegistry,
        address wormhole,
        bytes calldata response,
        GuardianSignature[] calldata signatures
    ) external {
        PerChainQueryResponse[] memory responses =
            CaliberAccountingCCQ.decodeAndVerifyQueryResponse(wormhole, response, signatures).responses;

        uint256 len = responses.length;
        for (uint256 i; i < len; ++i) {
            _handlePerChainQueryResponse($, tokenRegistry, chainRegistry, responses[i]);
        }
    }

    /// @dev Manages the migration from a pre-deposit vault to a machine, and initializes the machine's accounting state.
    /// @param $ The machine storage struct.
    /// @param preDepositVault The address of the pre-deposit vault.
    /// @param oracleRegistry The address of the oracle registry.
    function migrateFromPreDeposit(Machine.MachineStorage storage $, address preDepositVault, address oracleRegistry)
        external
    {
        IPreDepositVault(preDepositVault).migrateToMachine();

        address preDepositToken = IPreDepositVault(preDepositVault).depositToken();
        $._idleTokens.add(preDepositToken);

        $._lastTotalAum = _accountingValueOf(
            oracleRegistry, $._accountingToken, preDepositToken, IERC20(preDepositToken).balanceOf(address(this))
        );
        $._lastGlobalAccountingTime = block.timestamp;
    }

    /// @dev Calculates the share price based on given AUM, share supply and share token decimals offset.
    /// @param aum The AUM of the machine.
    /// @param supply The supply of the share token.
    /// @param shareTokenDecimalsOffset The decimals offset between share token and accounting token.
    /// @return The calculated share price.
    function getSharePrice(uint256 aum, uint256 supply, uint256 shareTokenDecimalsOffset)
        public
        pure
        returns (uint256)
    {
        return DecimalsUtils.SHARE_TOKEN_UNIT.mulDiv(aum + 1, supply + 10 ** shareTokenDecimalsOffset);
    }

    /// @dev Handles a received Wormhole CCQ PerChainQueryResponse object and updates the corresponding caliber accounting data in the machine storage.
    /// @param $ The machine storage struct.
    /// @param tokenRegistry The address of the token registry.
    /// @param chainRegistry The address of the chain registry.
    /// @param pcr The PerChainQueryResponse object containing the accounting data.
    function _handlePerChainQueryResponse(
        Machine.MachineStorage storage $,
        address tokenRegistry,
        address chainRegistry,
        PerChainQueryResponse memory pcr
    ) private {
        uint256 _evmChainId = IChainRegistry(chainRegistry).whToEvmChainId(pcr.chainId);

        IMachine.SpokeCaliberData storage caliberData = $._spokeCalibersData[_evmChainId];

        if (caliberData.mailbox == address(0)) {
            revert Errors.InvalidChainId();
        }

        // Decode and validate accounting data.
        (ICaliberMailbox.SpokeCaliberAccountingData memory accountingData, uint256 responseTimestamp) =
            CaliberAccountingCCQ.getAccountingData(pcr, caliberData.mailbox);

        // Validate that update is not older than current chain last update, nor stale.
        if (
            responseTimestamp <= caliberData.timestamp
                || (block.timestamp > responseTimestamp && block.timestamp - responseTimestamp >= $._caliberStaleThreshold)
        ) {
            revert Errors.StaleData();
        }

        // Update the spoke caliber data in the machine storage.
        caliberData.netAum = accountingData.netAum;
        caliberData.positions = accountingData.positions;
        caliberData.baseTokens = accountingData.baseTokens;
        caliberData.timestamp = responseTimestamp;
        _decodeAndMapBridgeAmounts(_evmChainId, accountingData.bridgesIn, caliberData.caliberBridgesIn, tokenRegistry);
        _decodeAndMapBridgeAmounts(_evmChainId, accountingData.bridgesOut, caliberData.caliberBridgesOut, tokenRegistry);
    }

    /// @dev Decodes (foreignToken, amount) pairs, resolves local tokens, and stores amounts in the map.
    function _decodeAndMapBridgeAmounts(
        uint256 chainId,
        bytes[] memory data,
        EnumerableMap.AddressToUintMap storage map,
        address tokenRegistry
    ) private {
        uint256 len = data.length;
        for (uint256 i; i < len; ++i) {
            (address foreignToken, uint256 amount) = abi.decode(data[i], (address, uint256));
            address localToken = ITokenRegistry(tokenRegistry).getLocalToken(foreignToken, chainId);
            map.set(localToken, amount);
        }
    }

    /// @dev Computes the total AUM of the machine.
    /// @param $ The machine storage struct.
    /// @param oracleRegistry The address of the oracle registry.
    function _getTotalAum(Machine.MachineStorage storage $, address oracleRegistry) private view returns (uint256) {
        uint256 totalAum;

        // spoke calibers net AUM
        uint256 currentTimestamp = block.timestamp;
        uint256 len = $._foreignChainIds.length;
        for (uint256 i; i < len; ++i) {
            uint256 chainId = $._foreignChainIds[i];
            IMachine.SpokeCaliberData storage spokeCaliberData = $._spokeCalibersData[chainId];
            if (
                currentTimestamp > spokeCaliberData.timestamp
                    && currentTimestamp - spokeCaliberData.timestamp >= $._caliberStaleThreshold
            ) {
                revert Errors.CaliberAccountingStale(chainId);
            }
            totalAum += spokeCaliberData.netAum;

            // check for funds received by machine but not declared by spoke caliber
            _checkBridgeState(spokeCaliberData.machineBridgesIn, spokeCaliberData.caliberBridgesOut);

            // check for funds received by spoke caliber but not declared by machine
            _checkBridgeState(spokeCaliberData.caliberBridgesIn, spokeCaliberData.machineBridgesOut);

            // check for funds sent by machine but not yet received by spoke caliber
            uint256 len2 = spokeCaliberData.machineBridgesOut.length();
            for (uint256 j; j < len2; ++j) {
                (address token, uint256 mOut) = spokeCaliberData.machineBridgesOut.at(j);
                (, uint256 cIn) = spokeCaliberData.caliberBridgesIn.tryGet(token);
                if (mOut > cIn) {
                    totalAum += _accountingValueOf(oracleRegistry, $._accountingToken, token, mOut - cIn);
                }
            }

            // check for funds sent by spoke caliber but not yet received by machine
            len2 = spokeCaliberData.caliberBridgesOut.length();
            for (uint256 j; j < len2; ++j) {
                (address token, uint256 cOut) = spokeCaliberData.caliberBridgesOut.at(j);
                (, uint256 mIn) = spokeCaliberData.machineBridgesIn.tryGet(token);
                if (cOut > mIn) {
                    totalAum += _accountingValueOf(oracleRegistry, $._accountingToken, token, cOut - mIn);
                }
            }
        }

        // hub caliber net AUM
        (uint256 hcAum,,) = ICaliber($._hubCaliber).getDetailedAum();
        totalAum += hcAum;

        // idle tokens
        len = $._idleTokens.length();
        for (uint256 i; i < len; ++i) {
            address token = $._idleTokens.at(i);
            totalAum +=
                _accountingValueOf(oracleRegistry, $._accountingToken, token, IERC20(token).balanceOf(address(this)));
        }

        return totalAum;
    }

    /// @dev Checks if the bridge state is consistent between the machine and spoke caliber.
    function _checkBridgeState(
        EnumerableMap.AddressToUintMap storage insMap,
        EnumerableMap.AddressToUintMap storage outsMap
    ) private view {
        uint256 len = insMap.length();
        for (uint256 i; i < len; ++i) {
            (address token, uint256 amountIn) = insMap.at(i);
            (, uint256 amountOut) = outsMap.tryGet(token);
            if (amountIn > amountOut) {
                revert Errors.BridgeStateMismatch();
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
        return amount.mulDiv(price, 10 ** DecimalsUtils._getDecimals(token));
    }
}
