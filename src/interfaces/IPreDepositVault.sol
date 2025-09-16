// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPreDepositVault {
    event Deposit(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);
    event MigrateToMachine(address indexed machine);
    event Redeem(address indexed owner, address indexed receiver, uint256 assets, uint256 shares);
    event RiskManagerChanged(address indexed oldRiskManager, address indexed newRiskManager);
    event ShareLimitChanged(uint256 indexed oldShareLimit, uint256 indexed newShareLimit);
    event UserWhitelistingChanged(address indexed user, bool indexed whitelisted);
    event WhitelistModeChanged(bool indexed enabled);

    struct PreDepositVaultInitParams {
        uint256 initialShareLimit;
        bool initialWhitelistMode;
        address initialRiskManager;
        address initialAuthority;
    }

    /// @notice Initializer of the contract.
    /// @param params The initialization parameters.
    /// @param shareToken The address of the share token.
    /// @param depositToken The address of the deposit token.
    /// @param accountingToken The address of the accounting token.
    function initialize(
        PreDepositVaultInitParams calldata params,
        address shareToken,
        address depositToken,
        address accountingToken
    ) external;

    /// @notice True if the vault has migrated to a machine instance, false otherwise.
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

    /// @notice Maximum amount of deposit tokens that can currently be deposited in the vault.
    function maxDeposit() external view returns (uint256);

    /// @notice Total amount of deposit tokens managed by the vault.
    function totalAssets() external view returns (uint256);

    /// @notice Amount of shares minted against a given amount of deposit tokens.
    /// @param assets The amount of deposit tokens to be deposited.
    function previewDeposit(uint256 assets) external view returns (uint256);

    /// @notice Amount of deposit tokens that can be withdrawn against a given amount of shares.
    /// @param assets The amount of shares to be redeemed.
    function previewRedeem(uint256 assets) external view returns (uint256);

    /// @notice Deposits a given amount of deposit tokens and mints shares to the receiver.
    /// @param assets The amount of deposit tokens to be deposited.
    /// @param receiver The receiver of the shares.
    /// @param minShares The minimum amount of shares to be minted.
    /// @return shares The amount of shares minted.
    function deposit(uint256 assets, address receiver, uint256 minShares) external returns (uint256);

    /// @notice Burns exactly shares from caller and transfers the corresponding amount of deposit tokens to the receiver.
    /// @param shares The amount of shares to be redeemed.
    /// @param receiver The receiver of withdrawn deposit tokens.
    /// @param minAssets The minimum amount of deposit tokens to be transferred.
    /// @return assets The amount of deposit tokens transferred.
    function redeem(uint256 shares, address receiver, uint256 minAssets) external returns (uint256);

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
