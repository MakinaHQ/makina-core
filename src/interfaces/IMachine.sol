// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IMachine {
    error CaliberAccountingStale(uint256 caliberChainId);
    error InvalidChainId();
    error InvalidDecimals();
    error ExceededMaxMint(uint256 shares, uint256 max);
    error NotMailbox();
    error RecoveryMode();
    error SpokeMailboxAlreadyExists();
    error SpokeMailboxDoesNotExist();
    error UnauthorizedDepositor();
    error UnauthorizedOperator();
    error UnexpectedResultLength();

    event CaliberStaleThresholdChanged(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    event Deposit(address indexed sender, address indexed receiver, uint256 assets, uint256 amount);
    event DepositorOnlyModeChanged(bool indexed restricted);
    event HubCaliberDeployed(address indexed caliber, address indexed mailbox);
    event ShareLimitChanged(uint256 indexed oldShareLimit, uint256 indexed newShareLimit);
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event RecoveryModeChanged(bool indexed enabled);
    event SecurityCouncilChanged(address indexed oldSecurityCouncil, address indexed newSecurityCouncil);
    event ShareTokenDeployed(address indexed shareToken);
    event SpokeMailboxDeployed(address spokeMailbox, uint256 indexed spokeChainId);
    event TotalAumUpdated(uint256 totalAum, uint256 timestamp);
    event TransferToCaliber(uint256 indexed chainId, address indexed token, uint256 amount);

    /// @notice Initialization parameters.
    /// @param accountingToken The address of the accounting token.
    /// @param initialMechanic The address of the initial mechanic.
    /// @param initialSecurityCouncil The address of the initial security council.
    /// @param initialAuthority The address of the initial authority.
    /// @param depositor The address of the optional depositor.
    /// @param initialCaliberStaleThreshold The caliber accounting staleness threshold in seconds.
    /// @param initialShareLimit The share cap value.
    /// @param hubCaliberAccountingTokenPosID The position ID of the hub caliber's accounting token.
    /// @param hubCaliberPosStaleThreshold The hub caliber's position accounting staleness threshold.
    /// @param hubCaliberAllowedInstrRoot The root of the Merkle tree containing allowed caliber instructions.
    /// @param hubCaliberTimelockDuration The duration of the hub caliber's Merkle tree root update timelock.
    /// @param hubCaliberMaxPositionIncreaseLossBps The max allowed value loss (in basis point) in the hub caliber when increasing a position.
    /// @param hubCaliberMaxPositionDecreaseLossBps The max allowed value loss (in basis point) in the hub caliber when decreasing a position.
    /// @param hubCaliberMaxSwapLossBps The max allowed value loss (in basis point) when swapping a base token into another in the hub caliber.
    /// @param depositorOnlyMode Whether deposits are restricted to the depositor.
    /// @param shareTokenName The name of the share token.
    /// @param shareTokenSymbol The symbol of the share token.
    struct MachineInitParams {
        address accountingToken;
        address initialMechanic;
        address initialSecurityCouncil;
        address initialAuthority;
        address depositor;
        uint256 initialCaliberStaleThreshold;
        uint256 initialShareLimit;
        uint256 hubCaliberAccountingTokenPosID;
        uint256 hubCaliberPosStaleThreshold;
        bytes32 hubCaliberAllowedInstrRoot;
        uint256 hubCaliberTimelockDuration;
        uint256 hubCaliberMaxPositionIncreaseLossBps;
        uint256 hubCaliberMaxPositionDecreaseLossBps;
        uint256 hubCaliberMaxSwapLossBps;
        bool depositorOnlyMode;
        string shareTokenName;
        string shareTokenSymbol;
    }

    struct SpokeCaliberData {
        uint256 chainId;
        address machineMailbox;
        uint256 timestamp;
        uint256 netAum;
        bytes[] positions; // abi.encode(positionId, positionSize)
        bytes[] totalReceivedFromHM; // abi.encode(baseToken, nativeValue)
        bytes[] totalSentToHM; // abi.encode(baseToken, nativeValue)
    }

    /// @notice Initializer of the contract.
    /// @param params The initialization parameters.
    function initialize(MachineInitParams calldata params) external;

    /// @notice Address of the registry.
    function registry() external view returns (address);

    /// @notice Address of the Wormhole Core Bridge.
    function wormhole() external view returns (address);

    /// @notice Address of the mechanic.
    function mechanic() external view returns (address);

    /// @notice Address of the security council.
    function securityCouncil() external view returns (address);

    /// @notice Address of the share token.
    function shareToken() external view returns (address);

    /// @notice Address of the accounting token.
    function accountingToken() external view returns (address);

    /// @notice Maximum duration a caliber can remain unaccounted for before it is considered stale.
    function caliberStaleThreshold() external view returns (uint256);

    /// @notice Share token supply limit that cannot be exceeded by new deposits.
    function shareLimit() external view returns (uint256);

    /// @notice Maximum amount of shares that can currently be minted through asset deposits.
    function maxMint() external view returns (uint256);

    /// @notice Wether deposits are restricted to the depositor.
    function depositorOnlyMode() external view returns (bool);

    /// @notice Whether the machine is in recovery mode.
    function recoveryMode() external view returns (bool);

    /// @notice Last total machine AUM.
    function lastTotalAum() external view returns (uint256);

    /// @notice Timestamp of the last global machine accounting.
    function lastGlobalAccountingTime() external view returns (uint256);

    /// @notice Returns whether a token is an idle token help by the machine.
    /// @param token The address of the token.
    function isIdleToken(address token) external view returns (bool);

    /// @notice Number of calibers associated with the machine.
    function getSpokeCalibersLength() external view returns (uint256);

    /// @notice Spoke caliber index => Spoke Chain ID.
    function getSpokeChainId(uint256 idx) external view returns (uint256);

    /// @notice Spoke Chain ID => Spoke Caliber Data.
    function getSpokeCaliberAccountingData(uint256 chainId) external view returns (SpokeCaliberData memory);

    /// @notice Returns the amount of shares that the Machine would exchange for the amount of assets provided.
    /// @param assets The amount of assets.
    /// @return shares The amount of shares.
    function convertToShares(uint256 assets) external view returns (uint256);

    /// @notice Notifies the machine of an incoming token transfer.
    /// @param token The address of the token.
    function notifyIncomingTransfer(address token) external;

    /// @notice Initiates a token transfers to a caliber.
    /// @param token The address of the token to transfer.
    /// @param amount The amount of token to transfer.
    /// @param chainId The chain ID of the caliber.
    function transferToCaliber(address token, uint256 amount, uint256 chainId) external;

    /// @notice Updates the total AUM of the machine.
    /// @return totalAum The updated total AUM.
    function updateTotalAum() external returns (uint256);

    /// @notice Deposits accounting tokens into the machine and mints shares to the receiver
    /// @param assets The amount of accounting tokens to deposit
    /// @param receiver The receiver of minted shares
    /// @return shares The amount of shares minted
    function deposit(uint256 assets, address receiver) external returns (uint256);

    /// @notice Deploys a new machine mailbox for a spoke caliber.
    /// @param chainId The foreign chain ID of the spoke caliber.
    function createSpokeMailbox(uint256 chainId) external returns (address);

    /// @notice Sets the spoke caliber mailbox in the machine mailbox associated to given spoke chain ID.
    /// @param chainId The foreign chain ID of the spoke caliber.
    /// @param spokeCaliberMailbox The address of the spoke caliber mailbox.
    function setSpokeCaliberMailbox(uint256 chainId, address spokeCaliberMailbox) external;

    /// @notice Sets a new mechanic.
    /// @param newMechanic The address of new mechanic.
    function setMechanic(address newMechanic) external;

    /// @notice Sets a new security council.
    /// @param newSecurityCouncil The address of the new security council.
    function setSecurityCouncil(address newSecurityCouncil) external;

    /// @notice Sets the caliber accounting staleness threshold.
    /// @param newCaliberStaleThreshold The new threshold in seconds.
    function setCaliberStaleThreshold(uint256 newCaliberStaleThreshold) external;

    /// @notice Sets the new share token supply limit that cannot be exceeded by new deposits.
    /// @param newShareLimit The new share limit
    function setShareLimit(uint256 newShareLimit) external;

    /// @notice Sets the deposit restriction status.
    /// @param isRestricted True to restrict deposits to the depositor, false to allow deposits from any address.
    function setDepositorOnlyMode(bool isRestricted) external;

    /// @notice Sets the recovery mode status.
    /// @param enabled True to enable recovery mode, false to disable.
    function setRecoveryMode(bool enabled) external;
}
