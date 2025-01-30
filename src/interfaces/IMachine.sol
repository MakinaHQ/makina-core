// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IMachine {
    error CaliberAccountingStale(uint256 caliberChainId);
    error InvalidDecimals();
    error MailboxAlreadyExists();
    error NotMailbox();
    error RecoveryMode();
    error UnauthorizedOperator();

    event HubCaliberDeployed(address indexed caliber, address indexed mailbox);
    event CaliberStaleThresholdChanged(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event RecoveryModeChanged(bool indexed enabled);
    event SecurityCouncilChanged(address indexed oldSecurityCouncil, address indexed newSecurityCouncil);
    event TotalAumUpdated(uint256 totalAum, uint256 timestamp);
    event TransferToCaliber(uint256 indexed chainId, address indexed token, uint256 amount);

    /// @notice Initialization parameters.
    /// @param accountingToken The address of the accounting token.
    /// @param initialMechanic The address of the initial mechanic.
    /// @param initialSecurityCouncil The address of the initial security council.
    /// @param initialAuthority The address of the initial authority.
    /// @param initialCaliberStaleThreshold The caliber accounting staleness threshold in seconds.
    /// @param hubCaliberAccountingTokenPosID The position ID of the hub caliber's accounting token.
    /// @param hubCaliberPosStaleThreshold The hub caliber's position accounting staleness threshold.
    /// @param hubCaliberAllowedInstrRoot The root of the Merkle tree containing allowed caliber instructions.
    /// @param hubCaliberTimelockDuration The duration of the hub caliber's Merkle tree root update timelock.
    /// @param hubCaliberMaxMgmtLossBps The max allowed value loss (in basis point) in the hub caliber when managing a position.
    /// @param hubCaliberMaxSwapLossBps The max allowed value loss (in basis point) when swapping a base token into another in the hub caliber.
    struct MachineInitParams {
        address accountingToken;
        address initialMechanic;
        address initialSecurityCouncil;
        address initialAuthority;
        uint256 initialCaliberStaleThreshold;
        uint256 hubCaliberAccountingTokenPosID;
        uint256 hubCaliberPosStaleThreshold;
        bytes32 hubCaliberAllowedInstrRoot;
        uint256 hubCaliberTimelockDuration;
        uint256 hubCaliberMaxMgmtLossBps;
        uint256 hubCaliberMaxSwapLossBps;
    }

    /// @notice Initializer of the contract.
    /// @param params The initialization parameters.
    function initialize(MachineInitParams calldata params) external;

    /// @notice Address of the registry.
    function registry() external view returns (address);

    /// @notice Address of the mechanic.
    function mechanic() external view returns (address);

    /// @notice Address of the security council.
    function securityCouncil() external view returns (address);

    /// @notice Address of the accounting token.
    function accountingToken() external view returns (address);

    /// @notice Maximum duration a caliber can remain unaccounted for before it is considered stale.
    function caliberStaleThreshold() external view returns (uint256);

    /// @notice Whether the machine is in recovery mode.
    function recoveryMode() external view returns (bool);

    /// @notice Last reported total machine AUM.
    function lastReportedTotalAum() external view returns (uint256);

    /// @notice Timestamp of the last reported total machine AUM.
    function lastReportedTotalAumTime() external view returns (uint256);

    /// @notice Number of calibers associated with the machine.
    function getCalibersLength() external view returns (uint256);

    /// @notice Returns the chain ID associated with the idx's caliber deployment.
    /// @param idx The index of the caliber deployment.
    /// @return chainId The chain ID of the caliber deployment.
    function getSupportedChainId(uint256 idx) external view returns (uint256);

    /// @notice Returns the mailbox for the caliber associated with the given chain ID.
    /// @param chainId The chain ID of the caliber deployment.
    /// @return mailbox The address of the mailbox.
    function getMailbox(uint256 chainId) external view returns (address);

    /// @notice Returns whether a token is an idle token help by the machine.
    /// @param token The address of the token.
    function isIdleToken(address token) external view returns (bool);

    /// @notice Notifies the machine of an incoming token transfer.
    /// @param token The address of the token.
    function notifyIncomingTransfer(address token) external;

    /// @notice Initiates a token transfers to a caliber.
    /// @param token The address of the token to transfer.
    /// @param amount The amount of token to transfer.
    /// @param chainId The chain ID of the caliber.
    function transferToCaliber(address token, uint256 amount, uint256 chainId) external;

    /// @notice Updates the total AUM of the machine.
    function updateTotalAum() external returns (uint256);

    /// @notice Sets a new mechanic.
    /// @param newMechanic The address of new mechanic.
    function setMechanic(address newMechanic) external;

    /// @notice Sets a new security council.
    /// @param newSecurityCouncil The address of the new security council.
    function setSecurityCouncil(address newSecurityCouncil) external;

    /// @notice Sets the caliber accounting staleness threshold.
    /// @param newCaliberStaleThreshold The new threshold in seconds.
    function setCaliberStaleThreshold(uint256 newCaliberStaleThreshold) external;

    /// @notice Sets the recovery mode.
    /// @param enabled True to enable recovery mode, false to disable.
    function setRecoveryMode(bool enabled) external;
}
