// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IHubRegistry} from "src/interfaces/IHubRegistry.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {IOwnable2Step} from "src/interfaces/IOwnable2Step.sol";
import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {DecimalsUtils} from "../libraries/DecimalsUtils.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

contract PreDepositVault is AccessManagedUpgradeable, MakinaContext, IPreDepositVault {
    using SafeERC20 for IERC20Metadata;
    using Math for uint256;

    /// @custom:storage-location erc7201:makina.storage.PreDepositVault
    struct PreDepositVaultStorage {
        address _depositToken;
        address _accountingToken;
        address _shareToken;
        uint256 _shareTokenDecimalsOffset;
        uint256 _shareLimit;
        address _riskManager;
        address _machine;
        bool _migrated;
        bool _whitelistMode;
        mapping(address => bool) _isWhitelistedUser;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.PreDepositVault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PreDepositVaultStorageLocation =
        0x88ccda4670a9221204e56c6b7ced9d52994799751a70ced770588fb180e5dd00;

    function _getPreDepositVaultStorage() private pure returns (PreDepositVaultStorage storage $) {
        assembly {
            $.slot := PreDepositVaultStorageLocation
        }
    }

    constructor(address _registry) MakinaContext(_registry) {
        _disableInitializers();
    }

    /// @inheritdoc IPreDepositVault
    function initialize(
        PreDepositVaultInitParams calldata params,
        address _shareToken,
        address _depositToken,
        address _accountingToken
    ) external override initializer {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();

        if (!IOracleRegistry(IHubRegistry(registry).oracleRegistry()).isFeedRouteRegistered(_depositToken)) {
            revert IOracleRegistry.PriceFeedRouteNotRegistered(_depositToken);
        }
        if (!IOracleRegistry(IHubRegistry(registry).oracleRegistry()).isFeedRouteRegistered(_accountingToken)) {
            revert IOracleRegistry.PriceFeedRouteNotRegistered(_accountingToken);
        }

        uint256 atDecimals = DecimalsUtils._getDecimals(_accountingToken);

        $._shareToken = _shareToken;
        $._depositToken = _depositToken;
        $._accountingToken = _accountingToken;
        $._shareTokenDecimalsOffset = DecimalsUtils.SHARE_TOKEN_DECIMALS - atDecimals;
        $._shareLimit = params.initialShareLimit;
        IOwnable2Step(_shareToken).acceptOwnership();

        $._riskManager = params.initialRiskManager;
        $._whitelistMode = params.initialWhitelistMode;

        __AccessManaged_init(params.initialAuthority);
    }

    modifier notMigrated() {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();
        if ($._migrated) {
            revert Migrated();
        }
        _;
    }

    /// @inheritdoc IPreDepositVault
    function migrated() external view override returns (bool) {
        return _getPreDepositVaultStorage()._migrated;
    }

    /// @inheritdoc IPreDepositVault
    function machine() external view override returns (address) {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();
        if (!$._migrated) {
            revert NotMigrated();
        }
        return $._machine;
    }

    /// @inheritdoc IPreDepositVault
    function riskManager() external view override returns (address) {
        return _getPreDepositVaultStorage()._riskManager;
    }

    /// @inheritdoc IPreDepositVault
    function whitelistMode() external view override returns (bool) {
        return _getPreDepositVaultStorage()._whitelistMode;
    }

    /// @inheritdoc IPreDepositVault
    function isWhitelistedUser(address user) external view override returns (bool) {
        return _getPreDepositVaultStorage()._isWhitelistedUser[user];
    }

    /// @inheritdoc IPreDepositVault
    function depositToken() external view override returns (address) {
        return _getPreDepositVaultStorage()._depositToken;
    }

    /// @inheritdoc IPreDepositVault
    function accountingToken() external view override returns (address) {
        return _getPreDepositVaultStorage()._accountingToken;
    }

    /// @inheritdoc IPreDepositVault
    function shareToken() external view override returns (address) {
        return _getPreDepositVaultStorage()._shareToken;
    }

    /// @inheritdoc IPreDepositVault
    function shareLimit() external view override returns (uint256) {
        return _getPreDepositVaultStorage()._shareLimit;
    }

    /// @inheritdoc IPreDepositVault
    function maxDeposit() public view override returns (uint256) {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();
        if ($._migrated) {
            return 0;
        }
        if ($._shareLimit == type(uint256).max) {
            return type(uint256).max;
        }
        uint256 _totalAssets = IERC20Metadata($._depositToken).balanceOf(address(this));
        uint256 _assetLimit = previewRedeem($._shareLimit);
        if (_totalAssets >= _assetLimit) {
            return 0;
        }
        return _assetLimit - _totalAssets;
    }

    /// @inheritdoc IPreDepositVault
    function totalAssets() external view override returns (uint256) {
        return IERC20Metadata(_getPreDepositVaultStorage()._depositToken).balanceOf(address(this));
    }

    /// @inheritdoc IPreDepositVault
    function previewDeposit(uint256 assets) public view override notMigrated returns (uint256) {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();

        address _depositToken = $._depositToken;
        uint256 price_d_a =
            IOracleRegistry(IHubRegistry(registry).oracleRegistry()).getPrice(_depositToken, $._accountingToken);
        uint256 dtUnit = 10 ** DecimalsUtils._getDecimals(_depositToken);
        uint256 dtBal = IERC20Metadata(_depositToken).balanceOf(address(this));
        uint256 stSupply = IERC20Metadata($._shareToken).totalSupply();

        // (dtUnit * atUnit * stUnit) / (dtUnit * atUnit) = stUnit
        return assets.mulDiv(price_d_a * (stSupply + 10 ** $._shareTokenDecimalsOffset), (dtBal * price_d_a) + dtUnit);
    }

    /// @inheritdoc IPreDepositVault
    function previewRedeem(uint256 shares) public view override notMigrated returns (uint256) {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();

        address _depositToken = $._depositToken;
        uint256 price_d_a =
            IOracleRegistry(IHubRegistry(registry).oracleRegistry()).getPrice(_depositToken, $._accountingToken);
        uint256 dtUnit = 10 ** DecimalsUtils._getDecimals(_depositToken);
        uint256 dtBal = IERC20Metadata(_depositToken).balanceOf(address(this));
        uint256 stSupply = IERC20Metadata($._shareToken).totalSupply();

        // (stUnit * dtUnit * atUnit) / (atUnit * stUnit) = dtUnit
        return shares.mulDiv((dtBal * price_d_a) + dtUnit, price_d_a * (stSupply + 10 ** $._shareTokenDecimalsOffset));
    }

    /// @inheritdoc IPreDepositVault
    function deposit(uint256 assets, address receiver, uint256 minShares)
        external
        override
        notMigrated
        returns (uint256)
    {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();

        if ($._whitelistMode && !$._isWhitelistedUser[msg.sender]) {
            revert UnauthorizedCaller();
        }

        if (assets > maxDeposit()) {
            revert ExceededMaxDeposit();
        }

        uint256 shares = previewDeposit(assets);
        if (shares < minShares) {
            revert SlippageProtection();
        }

        IERC20Metadata($._depositToken).safeTransferFrom(msg.sender, address(this), assets);
        IMachineShare($._shareToken).mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    /// @inheritdoc IPreDepositVault
    function redeem(uint256 shares, address receiver, uint256 minAssets)
        external
        override
        notMigrated
        returns (uint256)
    {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();

        if ($._whitelistMode && !$._isWhitelistedUser[msg.sender]) {
            revert UnauthorizedCaller();
        }

        uint256 assets = previewRedeem(shares);
        if (assets < minAssets) {
            revert SlippageProtection();
        }

        IMachineShare($._shareToken).burn(msg.sender, shares);
        IERC20Metadata($._depositToken).safeTransfer(receiver, assets);

        emit Redeem(msg.sender, receiver, assets, shares);

        return assets;
    }

    /// @inheritdoc IPreDepositVault
    function migrateToMachine() external override notMigrated {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();
        if (msg.sender != $._machine) {
            revert NotPendingMachine();
        }

        $._migrated = true;

        IERC20Metadata($._depositToken).safeTransfer(
            msg.sender, IERC20Metadata($._depositToken).balanceOf(address(this))
        );
        IOwnable2Step($._shareToken).transferOwnership(msg.sender);

        emit MigrateToMachine($._machine);
    }

    /// @inheritdoc IPreDepositVault
    function setPendingMachine(address _machine) external override notMigrated {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();
        if (msg.sender != IHubRegistry(registry).coreFactory()) {
            revert NotFactory();
        }
        $._machine = _machine;
    }

    /// @inheritdoc IPreDepositVault
    function setShareLimit(uint256 newShareLimit) external override notMigrated {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();
        if (msg.sender != $._riskManager) {
            revert UnauthorizedCaller();
        }
        emit ShareLimitChanged($._shareLimit, newShareLimit);
        $._shareLimit = newShareLimit;
    }

    /// @inheritdoc IPreDepositVault
    function setRiskManager(address _riskManager) external override restricted notMigrated {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();
        emit RiskManagerChanged($._riskManager, _riskManager);
        $._riskManager = _riskManager;
    }

    /// @inheritdoc IPreDepositVault
    function setWhitelistedUsers(address[] calldata users, bool whitelisted) external override restricted notMigrated {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();
        uint256 len = users.length;
        for (uint256 i = 0; i < len;) {
            $._isWhitelistedUser[users[i]] = whitelisted;
            emit UserWhitelistingChanged(users[i], whitelisted);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IPreDepositVault
    function setWhitelistMode(bool enabled) external override restricted notMigrated {
        PreDepositVaultStorage storage $ = _getPreDepositVaultStorage();
        $._whitelistMode = enabled;
        emit WhitelistModeChanged(enabled);
    }
}
