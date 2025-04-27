// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IPreDepositVault {
    error InvalidDecimals();
    error NotFactory();
    error NotPendingMachine();
    error NotMigrated();
    error Migrated();
    error SlippageProtection();
    error UnauthorizedCaller();

    event Deposit(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);
    event MigrateToMachine(address indexed machine);
    event WhitelistModeChanged(bool indexed enabled);
    event UserWhitelistingChanged(address indexed user, bool indexed whitelisted);
    event Redeem(address indexed owner, address indexed receiver, uint256 assets, uint256 shares);
    event RiskManagerChanged(address indexed oldRiskManager, address indexed newRiskManager);
    event ShareLimitChanged(uint256 indexed oldShareLimit, uint256 indexed newShareLimit);

    struct PreDepositVaultInitParams {
        address depositToken;
        address accountingToken;
        uint256 initialShareLimit;
        bool initialWhitelistMode;
        address initialRiskManager;
        address initialAuthority;
    }

    /// @notice Initializer of the contract.
    /// @param params The initialization parameters.
    function initialize(PreDepositVaultInitParams calldata params, address shareToken) external;

    /// @notice Whether the vault has migrated to a machine instance.
    function migrated() external view returns (bool);

    /// @notice Address of the machine, set during migration.
    function machine() external view returns (address);

    /// @notice Address of the risk manager.
    function riskManager() external view returns (address);

    /// @notice True if the vault is in whitelist mode, false otherwise.
    function whitelistMode() external view returns (bool);

    /// @notice User => Whitelisting status.
    function isWhitelistedUser(address user) external view returns (bool);

    /// @notice Address of the deposit token.
    function depositToken() external view returns (address);

    /// @notice Address of the accounting token.
    function accountingToken() external view returns (address);

    /// @notice Address of the share token.
    function shareToken() external view returns (address);

    /// @notice Share token supply limit that cannot be exceeded by new deposits.
    function shareLimit() external view returns (uint256);

    /// @notice Maximum amount of assets that can currently be deposited in the vault.
    function maxDeposit() external view returns (uint256);

    /// @notice Total amount of depositToken managed by the vault.
    function totalAssets() external view returns (uint256);

    /// @notice Amount of shares minted against a given amount of assets.
    /// @param amount The amount of assets to be deposited.
    function previewDeposit(uint256 amount) external view returns (uint256);

    /// @notice Amount of assets that can be withdrawn against a given amount of shares.
    /// @param amount The amount of shares to be redeemed.
    function previewRedeem(uint256 amount) external view returns (uint256);

    /// @notice Deposits a given amount of assets and mints shares to the receiver.
    /// @param amount The amount of assets to be deposited.
    /// @param receiver The receiver of the shares.
    /// @param minShares The minimum amount of shares to be minted.
    /// @return shares The amount of shares minted.
    function deposit(uint256 amount, address receiver, uint256 minShares) external returns (uint256);

    /// @notice Burns exactly shares from caller and transfers the corresponding amount of assets to the receiver.
    /// @param amount The amount of shares to be redeemed.
    /// @param receiver The receiver of withdrawn assets.
    /// @param minAssets The minimum amount of assets to be transferred.
    /// @return assets The amount of assets transferred.
    function redeem(uint256 amount, address receiver, uint256 minAssets) external returns (uint256);

    /// @notice Migrates the pre-deposit vault to the machine.
    function migrateToMachine() external;

    /// @notice Sets the machine address to migrate to.
    /// @param machine The address of the machine.
    function setPendingMachine(address machine) external;

    /// @notice Sets the risk manager address.
    /// @param newRiskManager The address of the new risk manager.
    function setRiskManager(address newRiskManager) external;

    /// @notice Sets the new share token supply limit that cannot be exceeded by new deposits.
    /// @param newShareLimit The new share limit
    function setShareLimit(uint256 newShareLimit) external;

    /// @notice Whitelist or unwhitelist a list of users.
    /// @param users The addresses of the users to update.
    /// @param whitelisted True to whitelist the users, false to unwhitelist.
    function setWhitelistedUsers(address[] calldata users, bool whitelisted) external;

    /// @notice Sets the whitelist mode for the vault.
    /// @dev In whitelist mode, only whitelisted users can deposit.
    /// @param enabled True to enable whitelist mode, false to disable.
    function setWhitelistMode(bool enabled) external;
}
