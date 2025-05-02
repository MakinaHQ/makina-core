// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";

import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "../interfaces/IBridgeController.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {IChainRegistry} from "../interfaces/IChainRegistry.sol";
import {IHubRegistry} from "../interfaces/IHubRegistry.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IMachineEndpoint} from "../interfaces/IMachineEndpoint.sol";
import {IMachineShare} from "../interfaces/IMachineShare.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";
import {IOwnable2Step} from "../interfaces/IOwnable2Step.sol";
import {ITokenRegistry} from "../interfaces/ITokenRegistry.sol";
import {BridgeController} from "../bridge/controller/BridgeController.sol";
import {DecimalsUtils} from "../libraries/DecimalsUtils.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";
import {MakinaGovernable} from "../utils/MakinaGovernable.sol";
import {MachineUtils} from "../libraries/MachineUtils.sol";

contract Machine is MakinaGovernable, BridgeController, ReentrancyGuardUpgradeable, IMachine {
    using Math for uint256;
    using SafeERC20 for IERC20Metadata;
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
        uint256 _maxFeeAccrualRate;
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

        uint256 atDecimals = IERC20Metadata(_accountingToken).decimals();
        if (atDecimals < DecimalsUtils.MIN_DECIMALS || atDecimals > DecimalsUtils.MAX_DECIMALS) {
            revert InvalidDecimals();
        }

        address oracleRegistry = IHubRegistry(registry).oracleRegistry();
        if (!IOracleRegistry(oracleRegistry).isFeedRouteRegistered(_accountingToken)) {
            revert IOracleRegistry.PriceFeedRouteNotRegistered(_accountingToken);
        }

        $._shareToken = _shareToken;
        $._accountingToken = _accountingToken;
        $._idleTokens.add(_accountingToken);
        $._shareTokenDecimalsOffset = DecimalsUtils.SHARE_TOKEN_DECIMALS - atDecimals;

        if (_preDepositVault != address(0)) {
            MachineUtils.migrateFromPreDeposit($, _preDepositVault, oracleRegistry);
            uint256 currentShareSupply = IERC20Metadata($._shareToken).totalSupply();
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
        $._maxFeeAccrualRate = mParams.initialMaxFeeAccrualRate;
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
    function maxFeeAccrualRate() external view override returns (uint256) {
        return _getMachineStorage()._maxFeeAccrualRate;
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
        uint256 totalSupply = IERC20Metadata($._shareToken).totalSupply();
        return totalSupply < $._shareLimit ? $._shareLimit - totalSupply : 0;
    }

    /// @inheritdoc IMachine
    function maxWithdraw() public view override returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        return IERC20Metadata($._accountingToken).balanceOf(address(this));
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
            revert InvalidChainId();
        }
        return (scData.netAum, scData.positions, scData.baseTokens, scData.timestamp);
    }

    /// @inheritdoc IMachine
    function getSpokeCaliberMailbox(uint256 chainId) external view returns (address) {
        SpokeCaliberData storage scData = _getMachineStorage()._spokeCalibersData[chainId];
        if (scData.mailbox == address(0)) {
            revert InvalidChainId();
        }
        return scData.mailbox;
    }

    /// @inheritdoc IMachine
    function getSpokeBridgeAdapter(uint256 chainId, IBridgeAdapter.Bridge bridgeId) external view returns (address) {
        SpokeCaliberData storage scData = _getMachineStorage()._spokeCalibersData[chainId];
        if (scData.mailbox == address(0)) {
            revert InvalidChainId();
        }
        address adapter = scData.bridgeAdapters[bridgeId];
        if (adapter == address(0)) {
            revert SpokeBridgeAdapterNotSet();
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
        return assets.mulDiv(
            IERC20Metadata($._shareToken).totalSupply() + 10 ** $._shareTokenDecimalsOffset, $._lastTotalAum + 1
        );
    }

    /// @inheritdoc IMachine
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        return shares.mulDiv(
            $._lastTotalAum + 1, IERC20Metadata($._shareToken).totalSupply() + 10 ** $._shareTokenDecimalsOffset
        );
    }

    /// @inheritdoc IMachineEndpoint
    function manageTransfer(address token, uint256 amount, bytes calldata data) external override nonReentrant {
        MachineStorage storage $ = _getMachineStorage();

        if (_isBridgeAdapter(msg.sender)) {
            (uint256 chainId, uint256 inputAmount, bool refund) = abi.decode(data, (uint256, uint256, bool));

            SpokeCaliberData storage caliberData = $._spokeCalibersData[chainId];

            if (caliberData.mailbox == address(0)) {
                revert InvalidChainId();
            }

            if (refund) {
                uint256 mOut = caliberData.machineBridgesOut.get(token);
                uint256 newMOut = mOut - inputAmount;
                caliberData.machineBridgesOut.set(token, newMOut);
                (, uint256 cIn) = caliberData.caliberBridgesIn.tryGet(token);
                if (cIn > newMOut) {
                    revert BridgeStateMismatch();
                }
            } else {
                (, uint256 mIn) = caliberData.machineBridgesIn.tryGet(token);
                uint256 newMIn = mIn + inputAmount;
                caliberData.machineBridgesIn.set(token, newMIn);
                (, uint256 cOut) = caliberData.caliberBridgesOut.tryGet(token);
                if (newMIn > cOut) {
                    revert BridgeStateMismatch();
                }
            }
        } else if (msg.sender != $._hubCaliber) {
            revert UnauthorizedSender();
        }

        IERC20Metadata(token).safeTransferFrom(msg.sender, address(this), amount);
        _notifyIdleToken(token);
    }

    /// @inheritdoc IMachine
    function transferToHubCaliber(address token, uint256 amount) external override notRecoveryMode {
        MachineStorage storage $ = _getMachineStorage();

        if (msg.sender != mechanic()) {
            revert UnauthorizedCaller();
        }

        if (!ICaliber($._hubCaliber).isBaseToken(token)) {
            revert ICaliber.NotBaseToken();
        }
        IERC20Metadata(token).safeTransfer($._hubCaliber, amount);

        emit TransferToCaliber($._hubChainId, token, amount);

        if (IERC20Metadata(token).balanceOf(address(this)) == 0 && token != $._accountingToken) {
            $._idleTokens.remove(token);
        }
    }

    /// @inheritdoc IMachine
    function transferToSpokeCaliber(
        IBridgeAdapter.Bridge bridgeId,
        uint256 chainId,
        address token,
        uint256 amount,
        uint256 minOutputAmount
    ) external override notRecoveryMode nonReentrant {
        MachineStorage storage $ = _getMachineStorage();

        if (msg.sender != mechanic()) {
            revert UnauthorizedCaller();
        }

        address outputToken = ITokenRegistry(IHubRegistry(registry).tokenRegistry()).getForeignToken(token, chainId);

        SpokeCaliberData storage caliberData = $._spokeCalibersData[chainId];

        if (caliberData.mailbox == address(0)) {
            revert InvalidChainId();
        }

        address recipient = caliberData.bridgeAdapters[bridgeId];
        if (recipient == address(0)) {
            revert SpokeBridgeAdapterNotSet();
        }

        (bool exists, uint256 mOut) = caliberData.machineBridgesOut.tryGet(token);
        caliberData.machineBridgesOut.set(token, exists ? mOut + amount : amount);

        _scheduleOutBridgeTransfer(bridgeId, chainId, recipient, token, amount, outputToken, minOutputAmount);

        emit TransferToCaliber(chainId, token, amount);

        if (IERC20Metadata(token).balanceOf(address(this)) == 0 && token != $._accountingToken) {
            $._idleTokens.remove(token);
        }
    }

    /// @inheritdoc IBridgeController
    function sendOutBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId, bytes calldata data)
        external
        override
        notRecoveryMode
    {
        if (msg.sender != mechanic()) {
            revert UnauthorizedCaller();
        }

        _sendOutBridgeTransfer(bridgeId, transferId, data);
    }

    /// @inheritdoc IBridgeController
    function authorizeInBridgeTransfer(IBridgeAdapter.Bridge bridgeId, bytes32 messageHash)
        external
        override
        onlyOperator
    {
        _authorizeInBridgeTransfer(bridgeId, messageHash);
    }

    /// @inheritdoc IBridgeController
    function claimInBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId) external override onlyOperator {
        _claimInBridgeTransfer(bridgeId, transferId);
    }

    /// @inheritdoc IBridgeController
    function cancelOutBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId)
        external
        override
        onlyOperator
    {
        _cancelOutBridgeTransfer(bridgeId, transferId);
    }

    /// @inheritdoc IMachine
    function updateTotalAum() public override nonReentrant notRecoveryMode returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();

        uint256 _lastTotalAum = MachineUtils.updateTotalAum($, IHubRegistry(registry).oracleRegistry());
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
            revert UnauthorizedDepositor();
        }

        uint256 shares = convertToShares(assets);
        uint256 _maxMint = maxMint();
        if (shares > _maxMint) {
            revert ExceededMaxMint(shares, _maxMint);
        }
        if (shares < minShares) {
            revert SlippageProtection();
        }

        IERC20Metadata($._accountingToken).safeTransferFrom(msg.sender, address(this), assets);
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
            revert UnauthorizedRedeemer();
        }

        uint256 assets = convertToAssets(shares);

        uint256 _maxWithdraw = maxWithdraw();
        if (assets > _maxWithdraw) {
            revert ExceededMaxWithdraw(assets, _maxWithdraw);
        }
        if (assets < minAssets) {
            revert SlippageProtection();
        }

        IERC20Metadata($._accountingToken).safeTransfer(receiver, assets);
        IMachineShare($._shareToken).burn(msg.sender, shares);
        $._lastTotalAum -= assets;
        emit Redeem(msg.sender, receiver, assets, shares);

        return assets;
    }

    /// @inheritdoc IMachine
    function updateSpokeCaliberAccountingData(bytes calldata response, IWormhole.Signature[] calldata signatures)
        external
        override
        nonReentrant
    {
        MachineUtils.updateSpokeCaliberAccountingData(
            _getMachineStorage(),
            IHubRegistry(registry).tokenRegistry(),
            IHubRegistry(registry).chainRegistry(),
            wormhole,
            response,
            signatures
        );
    }

    /// @inheritdoc IMachine
    function setSpokeCaliber(
        uint256 foreignChainId,
        address spokeCaliberMailbox,
        IBridgeAdapter.Bridge[] calldata bridges,
        address[] calldata adapters
    ) external restricted {
        if (!IChainRegistry(IHubRegistry(registry).chainRegistry()).isEvmChainIdRegistered(foreignChainId)) {
            revert IChainRegistry.EvmChainIdNotRegistered(foreignChainId);
        }

        MachineStorage storage $ = _getMachineStorage();
        SpokeCaliberData storage caliberData = $._spokeCalibersData[foreignChainId];

        if (caliberData.mailbox != address(0)) {
            revert SpokeCaliberAlreadySet();
        }
        $._foreignChainIds.push(foreignChainId);
        caliberData.mailbox = spokeCaliberMailbox;

        emit SpokeCaliberMailboxSet(foreignChainId, spokeCaliberMailbox);

        if (bridges.length != adapters.length) {
            revert MismatchedLength();
        }
        for (uint256 i; i < bridges.length;) {
            _setSpokeBridgeAdapter(foreignChainId, bridges[i], adapters[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IMachine
    function setSpokeBridgeAdapter(uint256 foreignChainId, IBridgeAdapter.Bridge bridgeId, address adapter)
        external
        override
        restricted
    {
        SpokeCaliberData storage caliberData = _getMachineStorage()._spokeCalibersData[foreignChainId];

        if (caliberData.mailbox == address(0)) {
            revert InvalidChainId();
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
    function setMaxFeeAccrualRate(uint256 newMaxFeeAccrualRate) external override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit MaxFeeAccrualRateChanged($._maxFeeAccrualRate, newMaxFeeAccrualRate);
        $._maxFeeAccrualRate = newMaxFeeAccrualRate;
    }

    /// @inheritdoc IMachine
    function setFeeMintCooldown(uint256 newFeeMintCooldown) external override restricted {
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
    function setOutTransferEnabled(IBridgeAdapter.Bridge bridgeId, bool enabled)
        external
        override
        onlyRiskManagerTimelock
    {
        _setOutTransferEnabled(bridgeId, enabled);
    }

    /// @inheritdoc IBridgeController
    function setMaxBridgeLossBps(IBridgeAdapter.Bridge bridgeId, uint256 maxBridgeLossBps)
        external
        override
        onlyRiskManagerTimelock
    {
        _setMaxBridgeLossBps(bridgeId, maxBridgeLossBps);
    }

    /// @inheritdoc IBridgeController
    function resetBridgingState(address token) external override restricted {
        MachineStorage storage $ = _getMachineStorage();
        uint256 len = $._foreignChainIds.length;
        for (uint256 i; i < len;) {
            SpokeCaliberData storage caliberData = $._spokeCalibersData[$._foreignChainIds[i]];

            caliberData.caliberBridgesIn.remove(token);
            caliberData.caliberBridgesOut.remove(token);
            caliberData.machineBridgesIn.remove(token);
            caliberData.machineBridgesOut.remove(token);

            unchecked {
                ++i;
            }
        }

        BridgeControllerStorage storage $bc = _getBridgeControllerStorage();
        len = $bc._supportedBridges.length;
        for (uint256 i; i < len;) {
            address bridgeAdapter = $bc._bridgeAdapters[$bc._supportedBridges[i]];
            IBridgeAdapter(bridgeAdapter).withdrawPendingFunds(token);
            unchecked {
                ++i;
            }
        }

        _notifyIdleToken(token);

        emit ResetBridgingState(token);
    }

    /// @dev Sets the spoke bridge adapter for a given foreign chain ID and bridge ID.
    function _setSpokeBridgeAdapter(uint256 foreignChainId, IBridgeAdapter.Bridge bridgeId, address adapter) internal {
        SpokeCaliberData storage caliberData = _getMachineStorage()._spokeCalibersData[foreignChainId];

        if (caliberData.bridgeAdapters[bridgeId] != address(0)) {
            revert SpokeBridgeAdapterAlreadySet();
        }
        if (adapter == address(0)) {
            revert ZeroBridgeAdapterAddress();
        }
        caliberData.bridgeAdapters[bridgeId] = adapter;

        emit SpokeBridgeAdapterSet(foreignChainId, uint256(bridgeId), adapter);
    }

    /// @dev Checks token balance, and registers token if needed.
    function _notifyIdleToken(address token) internal {
        if (IERC20Metadata(token).balanceOf(address(this)) > 0) {
            bool newlyAdded = _getMachineStorage()._idleTokens.add(token);
            if (newlyAdded && !IOracleRegistry(IHubRegistry(registry).oracleRegistry()).isFeedRouteRegistered(token)) {
                revert IOracleRegistry.PriceFeedRouteNotRegistered(token);
            }
        }
    }
}
