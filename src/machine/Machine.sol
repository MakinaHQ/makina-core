// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {GuardianSignature} from "@wormhole/sdk/libraries/VaaLib.sol";

import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "../interfaces/IBridgeController.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {IChainRegistry} from "../interfaces/IChainRegistry.sol";
import {IHubCoreRegistry} from "../interfaces/IHubCoreRegistry.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IMachineEndpoint} from "../interfaces/IMachineEndpoint.sol";
import {IMachineShare} from "../interfaces/IMachineShare.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";
import {IOwnable2Step} from "../interfaces/IOwnable2Step.sol";
import {ITokenRegistry} from "../interfaces/ITokenRegistry.sol";
import {BridgeController} from "../bridge/controller/BridgeController.sol";
import {Errors} from "../libraries/Errors.sol";
import {DecimalsUtils} from "../libraries/DecimalsUtils.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";
import {MakinaGovernable} from "../utils/MakinaGovernable.sol";
import {MachineUtils} from "../libraries/MachineUtils.sol";

contract Machine is MakinaGovernable, BridgeController, ReentrancyGuardUpgradeable, IMachine {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @inheritdoc IMachine
    address public immutable wormhole;

    /// @custom:storage-location erc7201:makina.storage.Machine
    struct MachineStorage {
        address _shareToken;
        address _accountingToken;
        address _depositor;
        address _redeemer;
        address _feeManager;
        uint256 _caliberStaleThreshold;
        uint256 _lastTotalAum;
        uint256 _lastGlobalAccountingTime;
        uint256 _lastMintedFeesTime;
        uint256 _lastMintedFeesSharePrice;
        uint256 _maxFixedFeeAccrualRate;
        uint256 _maxPerfFeeAccrualRate;
        uint256 _feeMintCooldown;
        uint256 _shareTokenDecimalsOffset;
        uint256 _shareLimit;
        uint256 _hubChainId;
        address _hubCaliber;
        uint256[] _foreignChainIds;
        mapping(uint256 foreignChainId => SpokeCaliberData data) _spokeCalibersData;
        EnumerableSet.AddressSet _idleTokens;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.Machine")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MachineStorageLocation = 0x55fe2a17e400bcd0e2125123a7fc955478e727b29a4c522f4f2bd95d961bd900;

    function _getMachineStorage() private pure returns (MachineStorage storage $) {
        assembly {
            $.slot := MachineStorageLocation
        }
    }

    constructor(address _registry, address _wormhole) MakinaContext(_registry) {
        wormhole = _wormhole;
        _disableInitializers();
    }

    /// @inheritdoc IMachine
    function initialize(
        MachineInitParams calldata mParams,
        MakinaGovernableInitParams calldata mgParams,
        address _preDepositVault,
        address _shareToken,
        address _accountingToken,
        address _hubCaliber
    ) external override initializer {
        MachineStorage storage $ = _getMachineStorage();

        $._hubChainId = block.chainid;
        $._hubCaliber = _hubCaliber;

        address oracleRegistry = IHubCoreRegistry(registry).oracleRegistry();
        if (!IOracleRegistry(oracleRegistry).isFeedRouteRegistered(_accountingToken)) {
            revert Errors.PriceFeedRouteNotRegistered(_accountingToken);
        }

        uint256 atDecimals = DecimalsUtils._getDecimals(_accountingToken);

        $._shareToken = _shareToken;
        $._accountingToken = _accountingToken;
        $._idleTokens.add(_accountingToken);
        $._shareTokenDecimalsOffset = DecimalsUtils.SHARE_TOKEN_DECIMALS - atDecimals;

        if (_preDepositVault != address(0)) {
            MachineUtils.migrateFromPreDeposit($, _preDepositVault, oracleRegistry);
            uint256 currentShareSupply = IERC20($._shareToken).totalSupply();
            $._lastMintedFeesSharePrice =
                MachineUtils.getSharePrice($._lastTotalAum, currentShareSupply, $._shareTokenDecimalsOffset);
        } else {
            $._lastMintedFeesSharePrice = 10 ** atDecimals;
        }

        IOwnable2Step(_shareToken).acceptOwnership();

        $._lastMintedFeesTime = block.timestamp;
        $._depositor = mParams.initialDepositor;
        $._redeemer = mParams.initialRedeemer;
        $._feeManager = mParams.initialFeeManager;
        $._caliberStaleThreshold = mParams.initialCaliberStaleThreshold;
        $._maxFixedFeeAccrualRate = mParams.initialMaxFixedFeeAccrualRate;
        $._maxPerfFeeAccrualRate = mParams.initialMaxPerfFeeAccrualRate;
        $._feeMintCooldown = mParams.initialFeeMintCooldown;
        $._shareLimit = mParams.initialShareLimit;
        __MakinaGovernable_init(mgParams);
    }

    /// @inheritdoc IMachine
    function depositor() external view override returns (address) {
        return _getMachineStorage()._depositor;
    }

    /// @inheritdoc IMachine
    function redeemer() external view override returns (address) {
        return _getMachineStorage()._redeemer;
    }

    /// @inheritdoc IMachine
    function shareToken() external view override returns (address) {
        return _getMachineStorage()._shareToken;
    }

    /// @inheritdoc IMachine
    function accountingToken() external view override returns (address) {
        return _getMachineStorage()._accountingToken;
    }

    /// @inheritdoc IMachine
    function hubCaliber() external view returns (address) {
        return _getMachineStorage()._hubCaliber;
    }

    /// @inheritdoc IMachine
    function feeManager() external view override returns (address) {
        return _getMachineStorage()._feeManager;
    }

    /// @inheritdoc IMachine
    function caliberStaleThreshold() external view override returns (uint256) {
        return _getMachineStorage()._caliberStaleThreshold;
    }

    /// @inheritdoc IMachine
    function maxFixedFeeAccrualRate() external view override returns (uint256) {
        return _getMachineStorage()._maxFixedFeeAccrualRate;
    }

    /// @inheritdoc IMachine
    function maxPerfFeeAccrualRate() external view override returns (uint256) {
        return _getMachineStorage()._maxPerfFeeAccrualRate;
    }

    /// @inheritdoc IMachine
    function feeMintCooldown() external view override returns (uint256) {
        return _getMachineStorage()._feeMintCooldown;
    }

    /// @inheritdoc IMachine
    function shareLimit() external view override returns (uint256) {
        return _getMachineStorage()._shareLimit;
    }

    /// @inheritdoc IMachine
    function maxMint() public view override returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        if ($._shareLimit == type(uint256).max) {
            return type(uint256).max;
        }
        uint256 totalSupply = IERC20($._shareToken).totalSupply();
        return totalSupply < $._shareLimit ? $._shareLimit - totalSupply : 0;
    }

    /// @inheritdoc IMachine
    function maxWithdraw() public view override returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        return IERC20($._accountingToken).balanceOf(address(this));
    }

    /// @inheritdoc IMachine
    function lastTotalAum() external view override returns (uint256) {
        return _getMachineStorage()._lastTotalAum;
    }

    /// @inheritdoc IMachine
    function lastGlobalAccountingTime() external view override returns (uint256) {
        return _getMachineStorage()._lastGlobalAccountingTime;
    }

    /// @inheritdoc IMachine
    function getSpokeCalibersLength() external view override returns (uint256) {
        return _getMachineStorage()._foreignChainIds.length;
    }

    /// @inheritdoc IMachine
    function getSpokeChainId(uint256 idx) external view override returns (uint256) {
        return _getMachineStorage()._foreignChainIds[idx];
    }

    /// @inheritdoc IMachine
    function getSpokeCaliberDetailedAum(uint256 chainId)
        external
        view
        override
        returns (uint256, bytes[] memory, bytes[] memory, uint256)
    {
        SpokeCaliberData storage scData = _getMachineStorage()._spokeCalibersData[chainId];
        if (scData.mailbox == address(0)) {
            revert Errors.InvalidChainId();
        }
        return (scData.netAum, scData.positions, scData.baseTokens, scData.timestamp);
    }

    /// @inheritdoc IMachine
    function getSpokeCaliberMailbox(uint256 chainId) external view returns (address) {
        SpokeCaliberData storage scData = _getMachineStorage()._spokeCalibersData[chainId];
        if (scData.mailbox == address(0)) {
            revert Errors.InvalidChainId();
        }
        return scData.mailbox;
    }

    /// @inheritdoc IMachine
    function getSpokeBridgeAdapter(uint256 chainId, uint16 bridgeId) external view returns (address) {
        SpokeCaliberData storage scData = _getMachineStorage()._spokeCalibersData[chainId];
        if (scData.mailbox == address(0)) {
            revert Errors.InvalidChainId();
        }
        address adapter = scData.bridgeAdapters[bridgeId];
        if (adapter == address(0)) {
            revert Errors.SpokeBridgeAdapterNotSet();
        }
        return adapter;
    }

    /// @inheritdoc IMachine
    function isIdleToken(address token) external view override returns (bool) {
        return _getMachineStorage()._idleTokens.contains(token);
    }

    /// @inheritdoc IMachine
    function convertToShares(uint256 assets) public view override returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        return
            assets.mulDiv(IERC20($._shareToken).totalSupply() + 10 ** $._shareTokenDecimalsOffset, $._lastTotalAum + 1);
    }

    /// @inheritdoc IMachine
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        return
            shares.mulDiv($._lastTotalAum + 1, IERC20($._shareToken).totalSupply() + 10 ** $._shareTokenDecimalsOffset);
    }

    /// @inheritdoc IMachineEndpoint
    function manageTransfer(address token, uint256 amount, bytes calldata data) external override nonReentrant {
        MachineStorage storage $ = _getMachineStorage();

        if (_isBridgeAdapter(msg.sender)) {
            (uint256 chainId, uint256 inputAmount, bool refund) = abi.decode(data, (uint256, uint256, bool));

            SpokeCaliberData storage caliberData = $._spokeCalibersData[chainId];

            if (caliberData.mailbox == address(0)) {
                revert Errors.InvalidChainId();
            }

            if (refund) {
                uint256 mOut = caliberData.machineBridgesOut.get(token);
                uint256 newMOut = mOut - inputAmount;
                (, uint256 cIn) = caliberData.caliberBridgesIn.tryGet(token);
                if (cIn > newMOut) {
                    revert Errors.BridgeStateMismatch();
                }
                caliberData.machineBridgesOut.set(token, newMOut);
            } else {
                (, uint256 mIn) = caliberData.machineBridgesIn.tryGet(token);
                uint256 newMIn = mIn + inputAmount;
                (, uint256 cOut) = caliberData.caliberBridgesOut.tryGet(token);
                if (newMIn > cOut) {
                    revert Errors.BridgeStateMismatch();
                }
                caliberData.machineBridgesIn.set(token, newMIn);
            }
        } else if (msg.sender != $._hubCaliber) {
            revert Errors.UnauthorizedCaller();
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _notifyIdleToken(token);
    }

    /// @inheritdoc IMachine
    function transferToHubCaliber(address token, uint256 amount) external override notRecoveryMode onlyMechanic {
        MachineStorage storage $ = _getMachineStorage();

        IERC20(token).forceApprove($._hubCaliber, amount);
        ICaliber($._hubCaliber).notifyIncomingTransfer(token, amount);

        emit TransferToCaliber($._hubChainId, token, amount);

        if (IERC20(token).balanceOf(address(this)) == 0 && token != $._accountingToken) {
            $._idleTokens.remove(token);
        }
    }

    /// @inheritdoc IMachine
    function transferToSpokeCaliber(
        uint16 bridgeId,
        uint256 chainId,
        address token,
        uint256 amount,
        uint256 minOutputAmount
    ) external override nonReentrant notRecoveryMode onlyMechanic {
        MachineStorage storage $ = _getMachineStorage();

        address outputToken = ITokenRegistry(IHubCoreRegistry(registry).tokenRegistry()).getForeignToken(token, chainId);

        SpokeCaliberData storage caliberData = $._spokeCalibersData[chainId];

        if (caliberData.mailbox == address(0)) {
            revert Errors.InvalidChainId();
        }

        address recipient = caliberData.bridgeAdapters[bridgeId];
        if (recipient == address(0)) {
            revert Errors.SpokeBridgeAdapterNotSet();
        }

        (bool exists, uint256 mOut) = caliberData.machineBridgesOut.tryGet(token);
        (, uint256 cIn) = caliberData.caliberBridgesIn.tryGet(token);
        if (mOut > cIn) {
            revert Errors.PendingBridgeTransfer();
        } else if (mOut < cIn) {
            revert Errors.BridgeStateMismatch();
        }
        caliberData.machineBridgesOut.set(token, exists ? mOut + amount : amount);

        _scheduleOutBridgeTransfer(bridgeId, chainId, recipient, token, amount, outputToken, minOutputAmount);

        emit TransferToCaliber(chainId, token, amount);

        if (IERC20(token).balanceOf(address(this)) == 0 && token != $._accountingToken) {
            $._idleTokens.remove(token);
        }
    }

    /// @inheritdoc IBridgeController
    function sendOutBridgeTransfer(uint16 bridgeId, uint256 transferId, bytes calldata data)
        external
        override
        notRecoveryMode
        onlyMechanic
    {
        _sendOutBridgeTransfer(bridgeId, transferId, data);
    }

    /// @inheritdoc IBridgeController
    function authorizeInBridgeTransfer(uint16 bridgeId, bytes32 messageHash) external override onlyOperator {
        _authorizeInBridgeTransfer(bridgeId, messageHash);
    }

    /// @inheritdoc IBridgeController
    function claimInBridgeTransfer(uint16 bridgeId, uint256 transferId) external override onlyOperator {
        _claimInBridgeTransfer(bridgeId, transferId);
    }

    /// @inheritdoc IBridgeController
    function cancelOutBridgeTransfer(uint16 bridgeId, uint256 transferId) external override onlyOperator {
        _cancelOutBridgeTransfer(bridgeId, transferId);
    }

    /// @inheritdoc IMachine
    function updateTotalAum() external override nonReentrant notRecoveryMode returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();

        uint256 _lastTotalAum = MachineUtils.updateTotalAum($, IHubCoreRegistry(registry).oracleRegistry());
        emit TotalAumUpdated(_lastTotalAum);

        uint256 _mintedFees = MachineUtils.manageFees($);
        if (_mintedFees != 0) {
            emit FeesMinted(_mintedFees);
        }

        return _lastTotalAum;
    }

    /// @inheritdoc IMachine
    function deposit(uint256 assets, address receiver, uint256 minShares)
        external
        nonReentrant
        notRecoveryMode
        returns (uint256)
    {
        MachineStorage storage $ = _getMachineStorage();

        if (msg.sender != $._depositor) {
            revert Errors.UnauthorizedCaller();
        }

        uint256 shares = convertToShares(assets);
        uint256 _maxMint = maxMint();
        if (shares > _maxMint) {
            revert Errors.ExceededMaxMint(shares, _maxMint);
        }
        if (shares < minShares) {
            revert Errors.SlippageProtection();
        }

        IERC20($._accountingToken).safeTransferFrom(msg.sender, address(this), assets);
        IMachineShare($._shareToken).mint(receiver, shares);
        $._lastTotalAum += assets;
        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    /// @inheritdoc IMachine
    function redeem(uint256 shares, address receiver, uint256 minAssets)
        external
        override
        nonReentrant
        notRecoveryMode
        returns (uint256)
    {
        MachineStorage storage $ = _getMachineStorage();

        if (msg.sender != $._redeemer) {
            revert Errors.UnauthorizedCaller();
        }

        uint256 assets = convertToAssets(shares);

        uint256 _maxWithdraw = maxWithdraw();
        if (assets > _maxWithdraw) {
            revert Errors.ExceededMaxWithdraw(assets, _maxWithdraw);
        }
        if (assets < minAssets) {
            revert Errors.SlippageProtection();
        }

        IERC20($._accountingToken).safeTransfer(receiver, assets);
        IMachineShare($._shareToken).burn(msg.sender, shares);
        $._lastTotalAum -= assets;
        emit Redeem(msg.sender, receiver, assets, shares);

        return assets;
    }

    /// @inheritdoc IMachine
    function updateSpokeCaliberAccountingData(bytes calldata response, GuardianSignature[] calldata signatures)
        external
        override
        nonReentrant
    {
        MachineUtils.updateSpokeCaliberAccountingData(
            _getMachineStorage(),
            IHubCoreRegistry(registry).tokenRegistry(),
            IHubCoreRegistry(registry).chainRegistry(),
            wormhole,
            response,
            signatures
        );
    }

    /// @inheritdoc IMachine
    function setSpokeCaliber(
        uint256 foreignChainId,
        address spokeCaliberMailbox,
        uint16[] calldata bridges,
        address[] calldata adapters
    ) external restricted {
        if (!IChainRegistry(IHubCoreRegistry(registry).chainRegistry()).isEvmChainIdRegistered(foreignChainId)) {
            revert Errors.EvmChainIdNotRegistered(foreignChainId);
        }

        MachineStorage storage $ = _getMachineStorage();
        SpokeCaliberData storage caliberData = $._spokeCalibersData[foreignChainId];

        if (caliberData.mailbox != address(0)) {
            revert Errors.SpokeCaliberAlreadySet();
        }
        $._foreignChainIds.push(foreignChainId);
        caliberData.mailbox = spokeCaliberMailbox;

        emit SpokeCaliberMailboxSet(foreignChainId, spokeCaliberMailbox);

        uint256 len = bridges.length;
        if (len != adapters.length) {
            revert Errors.MismatchedLength();
        }
        for (uint256 i; i < len; ++i) {
            _setSpokeBridgeAdapter(foreignChainId, bridges[i], adapters[i]);
        }
    }

    /// @inheritdoc IMachine
    function setSpokeBridgeAdapter(uint256 foreignChainId, uint16 bridgeId, address adapter)
        external
        override
        restricted
    {
        SpokeCaliberData storage caliberData = _getMachineStorage()._spokeCalibersData[foreignChainId];

        if (caliberData.mailbox == address(0)) {
            revert Errors.InvalidChainId();
        }
        _setSpokeBridgeAdapter(foreignChainId, bridgeId, adapter);
    }

    /// @inheritdoc IMachine
    function setDepositor(address newDepositor) external override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit DepositorChanged($._depositor, newDepositor);
        $._depositor = newDepositor;
    }

    /// @inheritdoc IMachine
    function setRedeemer(address newRedeemer) external override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit RedeemerChanged($._redeemer, newRedeemer);
        $._redeemer = newRedeemer;
    }

    /// @inheritdoc IMachine
    function setFeeManager(address newFeeManager) external override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit FeeManagerChanged($._feeManager, newFeeManager);
        $._feeManager = newFeeManager;
    }

    /// @inheritdoc IMachine
    function setCaliberStaleThreshold(uint256 newCaliberStaleThreshold) external override onlyRiskManagerTimelock {
        MachineStorage storage $ = _getMachineStorage();
        emit CaliberStaleThresholdChanged($._caliberStaleThreshold, newCaliberStaleThreshold);
        $._caliberStaleThreshold = newCaliberStaleThreshold;
    }

    /// @inheritdoc IMachine
    function setMaxFixedFeeAccrualRate(uint256 newMaxAccrualRate) external override onlyRiskManagerTimelock {
        MachineStorage storage $ = _getMachineStorage();
        emit MaxFixedFeeAccrualRateChanged($._maxFixedFeeAccrualRate, newMaxAccrualRate);
        $._maxFixedFeeAccrualRate = newMaxAccrualRate;
    }

    /// @inheritdoc IMachine
    function setMaxPerfFeeAccrualRate(uint256 newMaxAccrualRate) external override onlyRiskManagerTimelock {
        MachineStorage storage $ = _getMachineStorage();
        emit MaxPerfFeeAccrualRateChanged($._maxPerfFeeAccrualRate, newMaxAccrualRate);
        $._maxPerfFeeAccrualRate = newMaxAccrualRate;
    }

    /// @inheritdoc IMachine
    function setFeeMintCooldown(uint256 newFeeMintCooldown) external override onlyRiskManagerTimelock {
        MachineStorage storage $ = _getMachineStorage();
        emit FeeMintCooldownChanged($._feeMintCooldown, newFeeMintCooldown);
        $._feeMintCooldown = newFeeMintCooldown;
    }

    /// @inheritdoc IMachine
    function setShareLimit(uint256 newShareLimit) external override onlyRiskManager {
        MachineStorage storage $ = _getMachineStorage();
        emit ShareLimitChanged($._shareLimit, newShareLimit);
        $._shareLimit = newShareLimit;
    }

    /// @inheritdoc IBridgeController
    function setOutTransferEnabled(uint16 bridgeId, bool enabled) external override onlyRiskManagerTimelock {
        _setOutTransferEnabled(bridgeId, enabled);
    }

    /// @inheritdoc IBridgeController
    function setMaxBridgeLossBps(uint16 bridgeId, uint256 maxBridgeLossBps) external override onlyRiskManagerTimelock {
        _setMaxBridgeLossBps(bridgeId, maxBridgeLossBps);
    }

    /// @inheritdoc IBridgeController
    function resetBridgingState(address token) external override onlySecurityCouncil {
        MachineStorage storage $ = _getMachineStorage();
        uint256 len = $._foreignChainIds.length;
        for (uint256 i; i < len; ++i) {
            SpokeCaliberData storage caliberData = $._spokeCalibersData[$._foreignChainIds[i]];

            caliberData.caliberBridgesIn.remove(token);
            caliberData.caliberBridgesOut.remove(token);
            caliberData.machineBridgesIn.remove(token);
            caliberData.machineBridgesOut.remove(token);
        }

        BridgeControllerStorage storage $bc = _getBridgeControllerStorage();
        len = $bc._supportedBridges.length;
        for (uint256 i; i < len; ++i) {
            address bridgeAdapter = $bc._bridgeAdapters[$bc._supportedBridges[i]];
            IBridgeAdapter(bridgeAdapter).withdrawPendingFunds(token);
        }

        _notifyIdleToken(token);

        emit BridgingStateReset(token);
    }

    /// @dev Sets the spoke bridge adapter for a given foreign chain ID and bridge ID.
    function _setSpokeBridgeAdapter(uint256 foreignChainId, uint16 bridgeId, address adapter) internal {
        SpokeCaliberData storage caliberData = _getMachineStorage()._spokeCalibersData[foreignChainId];

        if (caliberData.bridgeAdapters[bridgeId] != address(0)) {
            revert Errors.SpokeBridgeAdapterAlreadySet();
        }
        if (adapter == address(0)) {
            revert Errors.ZeroBridgeAdapterAddress();
        }
        caliberData.bridgeAdapters[bridgeId] = adapter;

        emit SpokeBridgeAdapterSet(foreignChainId, uint256(bridgeId), adapter);
    }

    /// @dev Checks token balance, and registers token if needed.
    function _notifyIdleToken(address token) internal {
        if (IERC20(token).balanceOf(address(this)) > 0) {
            bool newlyAdded = _getMachineStorage()._idleTokens.add(token);
            if (
                newlyAdded && !IOracleRegistry(IHubCoreRegistry(registry).oracleRegistry()).isFeedRouteRegistered(token)
            ) {
                revert Errors.PriceFeedRouteNotRegistered(token);
            }
        }
    }
}
