// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";
import {EthCallQueryResponse} from "@wormhole/sdk/libraries/QueryResponse.sol";
import {QueryResponse} from "@wormhole/sdk/libraries/QueryResponse.sol";
import {QueryResponseLib} from "@wormhole/sdk/libraries/QueryResponse.sol";

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
import {ICaliberMailbox} from "../interfaces/ICaliberMailbox.sol";
import {ITokenRegistry} from "../interfaces/ITokenRegistry.sol";
import {BridgeController} from "../bridge/controller/BridgeController.sol";
import {Constants} from "../libraries/Constants.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

contract Machine is AccessManagedUpgradeable, BridgeController, IMachine {
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
        address _mechanic;
        address _securityCouncil;
        address _depositor;
        address _redeemer;
        uint256 _caliberStaleThreshold;
        uint256 _lastTotalAum;
        uint256 _lastGlobalAccountingTime;
        uint256 _shareTokenDecimalsOffset;
        uint256 _shareLimit;
        bool _recoveryMode;
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
    function initialize(MachineInitParams calldata params, address _shareToken, address _hubCaliber)
        external
        override
        initializer
    {
        MachineStorage storage $ = _getMachineStorage();

        uint256 atDecimals = IERC20Metadata(params.accountingToken).decimals();
        uint256 stDecimals = IERC20Metadata(_shareToken).decimals();
        if (
            atDecimals < Constants.MIN_ACCOUNTING_TOKEN_DECIMALS || atDecimals > Constants.MAX_ACCOUNTING_TOKEN_DECIMALS
                || stDecimals < atDecimals
        ) {
            revert InvalidDecimals();
        }
        if (!IOracleRegistry(IHubRegistry(registry).oracleRegistry()).isFeedRouteRegistered(params.accountingToken)) {
            revert IOracleRegistry.PriceFeedRouteNotRegistered(params.accountingToken);
        }
        $._accountingToken = params.accountingToken;
        $._idleTokens.add(params.accountingToken);

        IOwnable2Step(_shareToken).acceptOwnership();
        $._shareToken = _shareToken;
        $._shareTokenDecimalsOffset = stDecimals - atDecimals;

        $._mechanic = params.initialMechanic;
        $._securityCouncil = params.initialSecurityCouncil;
        $._depositor = params.initialDepositor;
        $._redeemer = params.initialRedeemer;
        $._caliberStaleThreshold = params.initialCaliberStaleThreshold;
        $._shareLimit = params.initialShareLimit;
        __AccessManaged_init(params.initialAuthority);

        $._hubChainId = block.chainid;
        $._hubCaliber = _hubCaliber;
    }

    modifier onlyMechanic() {
        MachineStorage storage $ = _getMachineStorage();
        if (msg.sender != $._mechanic) {
            revert UnauthorizedOperator();
        }
        _;
    }

    modifier onlyOperator() {
        MachineStorage storage $ = _getMachineStorage();
        if (msg.sender != ($._recoveryMode ? $._securityCouncil : $._mechanic)) {
            revert UnauthorizedOperator();
        }
        _;
    }

    modifier onlyDepositor() {
        MachineStorage storage $ = _getMachineStorage();
        if (msg.sender != $._depositor) {
            revert UnauthorizedDepositor();
        }
        _;
    }

    modifier onlyRedeemer() {
        MachineStorage storage $ = _getMachineStorage();
        if (msg.sender != $._redeemer) {
            revert UnauthorizedRedeemer();
        }
        _;
    }

    modifier notRecoveryMode() {
        MachineStorage storage $ = _getMachineStorage();
        if ($._recoveryMode) {
            revert RecoveryMode();
        }
        _;
    }

    /// @inheritdoc IMachine
    function mechanic() external view override returns (address) {
        return _getMachineStorage()._mechanic;
    }

    /// @inheritdoc IMachine
    function securityCouncil() external view override returns (address) {
        return _getMachineStorage()._securityCouncil;
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
    function caliberStaleThreshold() external view override returns (uint256) {
        return _getMachineStorage()._caliberStaleThreshold;
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
    function recoveryMode() external view override returns (bool) {
        return _getMachineStorage()._recoveryMode;
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
    function getSpokeCaliberAccountingData(uint256 chainId)
        external
        view
        override
        returns (ICaliberMailbox.SpokeCaliberAccountingData memory, uint256 timestamp)
    {
        MachineStorage storage $ = _getMachineStorage();
        SpokeCaliberData storage scData = $._spokeCalibersData[chainId];
        if (scData.mailbox == address(0)) {
            revert InvalidChainId();
        }
        return (
            ICaliberMailbox.SpokeCaliberAccountingData(
                scData.netAum, scData.positions, scData.baseTokens, scData.caliberBridgesIn, scData.caliberBridgesOut
            ),
            scData.timestamp
        );
    }

    /// @inheritdoc IMachine
    function getSpokeCaliberMailbox(uint256 chainId) external view returns (address) {
        MachineStorage storage $ = _getMachineStorage();
        SpokeCaliberData storage scData = $._spokeCalibersData[chainId];
        if (scData.mailbox == address(0)) {
            revert InvalidChainId();
        }
        return scData.mailbox;
    }

    /// @inheritdoc IMachine
    function getSpokeBridgeAdapter(uint256 chainId, IBridgeAdapter.Bridge bridgeId) external view returns (address) {
        MachineStorage storage $ = _getMachineStorage();
        SpokeCaliberData storage scData = $._spokeCalibersData[chainId];
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
    function convertToShares(uint256 assets) external view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @inheritdoc IMachine
    function convertToAssets(uint256 shares) external view override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /// @inheritdoc IMachineEndpoint
    function manageTransfer(address token, uint256 amount, bytes calldata data) external override {
        MachineStorage storage $ = _getMachineStorage();

        if (_isAdapter(msg.sender)) {
            (uint256 chainId, uint256 inputAmount) = abi.decode(data, (uint256, uint256));

            SpokeCaliberData storage caliberData = $._spokeCalibersData[chainId];

            if (caliberData.mailbox == address(0)) {
                revert InvalidChainId();
            }

            (bool exists, uint256 bridgeIn) = caliberData.machineBridgesIn.tryGet(token);
            caliberData.machineBridgesIn.set(token, exists ? bridgeIn + inputAmount : inputAmount);
        } else if (msg.sender != $._hubCaliber) {
            revert UnauthorizedSender();
        }

        IERC20Metadata(token).safeTransferFrom(msg.sender, address(this), amount);

        if (IERC20Metadata(token).balanceOf(address(this)) > 0) {
            bool newlyAdded = $._idleTokens.add(token);
            if (newlyAdded && !IOracleRegistry(IHubRegistry(registry).oracleRegistry()).isFeedRouteRegistered(token)) {
                revert IOracleRegistry.PriceFeedRouteNotRegistered(token);
            }
        }
    }

    /// @inheritdoc IMachine
    function transferToHubCaliber(address token, uint256 amount) external override notRecoveryMode onlyMechanic {
        MachineStorage storage $ = _getMachineStorage();

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
    ) external override notRecoveryMode onlyMechanic {
        address outputToken = ITokenRegistry(IHubRegistry(registry).tokenRegistry()).getForeignToken(token, chainId);

        MachineStorage storage $ = _getMachineStorage();
        SpokeCaliberData storage caliberData = $._spokeCalibersData[chainId];

        if (caliberData.mailbox == address(0)) {
            revert InvalidChainId();
        }

        address recipient = caliberData.bridgeAdapters[bridgeId];
        if (recipient == address(0)) {
            revert SpokeBridgeAdapterNotSet();
        }

        (bool exists, uint256 bridgeOut) = caliberData.machineBridgesOut.tryGet(token);
        caliberData.machineBridgesOut.set(token, exists ? bridgeOut + amount : amount);

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
        onlyMechanic
    {
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
    function updateTotalAum() external override notRecoveryMode returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        uint256 totalAum = _getTotalAum();
        uint256 currentTimestamp = block.timestamp;
        emit TotalAumUpdated(totalAum, currentTimestamp);
        $._lastTotalAum = totalAum;
        $._lastGlobalAccountingTime = currentTimestamp;
        return totalAum;
    }

    /// @inheritdoc IMachine
    function deposit(uint256 assets, address receiver) external notRecoveryMode onlyDepositor returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        uint256 shares = _convertToShares(assets, Math.Rounding.Floor);
        uint256 _maxMint = maxMint();
        if (shares > _maxMint) {
            revert ExceededMaxMint(shares, _maxMint);
        }

        IERC20Metadata($._accountingToken).safeTransferFrom(msg.sender, address(this), assets);
        IMachineShare($._shareToken).mint(receiver, shares);
        $._lastTotalAum += assets;
        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver) external notRecoveryMode onlyRedeemer returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        uint256 assets = _convertToAssets(shares, Math.Rounding.Floor);

        uint256 _maxWithdraw = maxWithdraw();
        if (assets > _maxWithdraw) {
            revert ExceededMaxWithdraw(assets, _maxWithdraw);
        }

        IERC20Metadata($._accountingToken).safeTransfer(receiver, assets);
        IMachineShare($._shareToken).burn(msg.sender, shares);
        $._lastTotalAum -= assets;
        emit Redeem(msg.sender, receiver, assets, shares);

        return assets;
    }

    function updateSpokeCaliberAccountingData(bytes memory response, IWormhole.Signature[] memory signatures)
        external
    {
        MachineStorage storage $ = _getMachineStorage();

        QueryResponse memory r = QueryResponseLib.parseAndVerifyQueryResponse(wormhole, response, signatures);
        uint256 numResponses = r.responses.length;

        for (uint256 i; i < numResponses;) {
            uint16 _wmChainId = r.responses[i].chainId;
            uint256 _evmChainId = IChainRegistry(IHubRegistry(registry).chainRegistry()).whToEvmChainId(_wmChainId);
            SpokeCaliberData storage caliberData = $._spokeCalibersData[_evmChainId];
            if (caliberData.mailbox == address(0)) {
                revert InvalidChainId();
            }

            EthCallQueryResponse memory eqr = QueryResponseLib.parseEthCallQueryResponse(r.responses[i]);

            // Validate that update is not older than current chain last update, nor stale.
            uint256 responseTimestamp = eqr.blockTime / QueryResponseLib.MICROSECONDS_PER_SECOND;
            if (
                responseTimestamp < caliberData.timestamp
                    || (
                        block.timestamp > responseTimestamp
                            && block.timestamp - responseTimestamp >= $._caliberStaleThreshold
                    )
            ) {
                revert StaleData();
            }

            // Validate that only one result is returned.
            if (eqr.results.length != 1) {
                revert UnexpectedResultLength();
            }

            // Validate addresses and function signatures.
            address[] memory validAddresses = new address[](1);
            bytes4[] memory validFunctionSignatures = new bytes4[](1);
            validAddresses[0] = caliberData.mailbox;
            validFunctionSignatures[0] = ICaliberMailbox.getSpokeCaliberAccountingData.selector;
            QueryResponseLib.validateEthCallRecord(eqr.results[0], validAddresses, validFunctionSignatures);

            // Decode and update accounting data.
            ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
                abi.decode(eqr.results[0].result, (ICaliberMailbox.SpokeCaliberAccountingData));
            caliberData.netAum = accountingData.netAum;
            caliberData.positions = accountingData.positions;
            caliberData.baseTokens = accountingData.baseTokens;
            caliberData.caliberBridgesIn = accountingData.bridgesIn;
            caliberData.caliberBridgesOut = accountingData.bridgesOut;
            caliberData.timestamp = responseTimestamp;

            unchecked {
                ++i;
            }
        }
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
            if (caliberData.bridgeAdapters[bridges[i]] != address(0)) {
                revert SpokeBridgeAdapterAlreadySet();
            }
            if (adapters[i] == address(0)) {
                revert ZeroBridgeAdapterAddress();
            }
            caliberData.bridgeAdapters[bridges[i]] = adapters[i];

            emit SpokeBridgeAdapterSet(foreignChainId, uint256(bridges[i]), adapters[i]);

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
        MachineStorage storage $ = _getMachineStorage();
        SpokeCaliberData storage caliberData = $._spokeCalibersData[foreignChainId];

        if (caliberData.mailbox == address(0)) {
            revert InvalidChainId();
        }
        if (caliberData.bridgeAdapters[bridgeId] != address(0)) {
            revert SpokeBridgeAdapterAlreadySet();
        }
        if (adapter == address(0)) {
            revert ZeroBridgeAdapterAddress();
        }
        caliberData.bridgeAdapters[bridgeId] = adapter;

        emit SpokeBridgeAdapterSet(foreignChainId, uint256(bridgeId), adapter);
    }

    /// @inheritdoc IMachine
    function setMechanic(address newMechanic) external override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit MechanicChanged($._mechanic, newMechanic);
        $._mechanic = newMechanic;
    }

    /// @inheritdoc IMachine
    function setSecurityCouncil(address newSecurityCouncil) external override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit SecurityCouncilChanged($._securityCouncil, newSecurityCouncil);
        $._securityCouncil = newSecurityCouncil;
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
    function setCaliberStaleThreshold(uint256 newCaliberStaleThreshold) external override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit CaliberStaleThresholdChanged($._caliberStaleThreshold, newCaliberStaleThreshold);
        $._caliberStaleThreshold = newCaliberStaleThreshold;
    }

    /// @inheritdoc IMachine
    function setShareLimit(uint256 newShareLimit) external override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit ShareLimitChanged($._shareLimit, newShareLimit);
        $._shareLimit = newShareLimit;
    }

    /// @inheritdoc IMachine
    function setRecoveryMode(bool enabled) external override restricted {
        MachineStorage storage $ = _getMachineStorage();
        if ($._recoveryMode != enabled) {
            $._recoveryMode = enabled;
            emit RecoveryModeChanged(enabled);
        }
    }

    /// @dev Computes the total AUM of the machine.
    function _getTotalAum() internal view returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        uint256 totalAum;

        // hub caliber net AUM
        (uint256 hcAum,,) = ICaliber($._hubCaliber).getDetailedAum();
        totalAum += hcAum;

        uint256 currentTimestamp = block.timestamp;
        uint256 len = $._foreignChainIds.length;
        for (uint256 i; i < len;) {
            uint256 chainId = $._foreignChainIds[i];
            SpokeCaliberData storage spokeCaliberData = $._spokeCalibersData[chainId];
            if (
                currentTimestamp > spokeCaliberData.timestamp
                    && currentTimestamp - spokeCaliberData.timestamp >= $._caliberStaleThreshold
            ) {
                revert CaliberAccountingStale(chainId);
            }
            totalAum += spokeCaliberData.netAum;
            // @TODO take async fund bridging into account

            unchecked {
                ++i;
            }
        }

        // idle tokens
        len = $._idleTokens.length();
        for (uint256 i; i < len;) {
            address token = $._idleTokens.at(i);
            totalAum += _accountingValueOf(token, IERC20Metadata(token).balanceOf(address(this)));
            unchecked {
                ++i;
            }
        }
        return totalAum;
    }

    /// @dev Computes the accounting value of a given token amount.
    function _accountingValueOf(address token, uint256 amount) internal view returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        uint256 price = IOracleRegistry(IHubRegistry(registry).oracleRegistry()).getPrice(token, $._accountingToken);
        return amount.mulDiv(price, (10 ** IERC20Metadata(token).decimals()));
    }

    /// @dev Converts accounting token amount to share amount, with support for rounding direction.
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        return assets.mulDiv(
            IERC20Metadata($._shareToken).totalSupply() + 10 ** $._shareTokenDecimalsOffset,
            $._lastTotalAum + 1,
            rounding
        );
    }

    /// @dev Converts share amount to accounting token amount, with support for rounding direction.
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        return shares.mulDiv(
            $._lastTotalAum + 1,
            IERC20Metadata($._shareToken).totalSupply() + 10 ** $._shareTokenDecimalsOffset,
            rounding
        );
    }
}
