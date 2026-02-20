// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IMakinaGovernable {
    event AccountingAgentAdded(address indexed newAgent);
    event AccountingAgentRemoved(address indexed agent);
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event RecoveryModeChanged(bool recoveryMode);
    event RestrictedAccountingModeChanged(bool restrictedAccountingMode);
    event RiskManagerChanged(address indexed oldRiskManager, address indexed newRiskManager);
    event RiskManagerTimelockChanged(address indexed oldRiskManagerTimelock, address indexed newRiskManagerTimelock);
    event SecurityCouncilChanged(address indexed oldSecurityCouncil, address indexed newSecurityCouncil);

    /// @notice Initialization parameters.
    /// @param initialMechanic The address of the initial mechanic.
    /// @param initialSecurityCouncil The address of the initial security council.
    /// @param initialRiskManager The address of the initial risk manager.
    /// @param initialRiskManagerTimelock The address of the initial risk manager timelock.
    /// @param initialAuthority The address of the initial authority.
    /// @param initialRestrictedAccountingMode The initial value for the restricted accounting mode.
    /// @param initialAccountingAgents The addresses of the initial accounting agents.
    struct MakinaGovernableInitParams {
        address initialMechanic;
        address initialSecurityCouncil;
        address initialRiskManager;
        address initialRiskManagerTimelock;
        address initialAuthority;
        bool initialRestrictedAccountingMode;
        address[] initialAccountingAgents;
    }

    /// @notice Address of the mechanic.
    function mechanic() external view returns (address);

    /// @notice Address of the security council.
    function securityCouncil() external view returns (address);

    /// @notice Address of the risk manager.
    function riskManager() external view returns (address);

    /// @notice Address of the risk manager timelock.
    function riskManagerTimelock() external view returns (address);

    /// @notice True if the contract is in recovery mode, false otherwise.
    function recoveryMode() external view returns (bool);

    /// @notice True if the contract is in restricted accounting mode, false otherwise.
    function restrictedAccountingMode() external view returns (bool);

    /// @notice User => Whether the user is an accounting agent
    function isAccountingAgent(address agent) external view returns (bool);

    /// @notice User => Whether the user is the current operator
    ///         The operator is either the mechanic or the security council depending on the recovery mode.
    function isOperator(address user) external view returns (bool);

    /// @notice User => Whether the user is authorized to perform accounting operations under current settings
    function isAccountingAuthorized(address user) external view returns (bool);

    /// @notice Sets a new mechanic.
    /// @param newMechanic The address of new mechanic.
    function setMechanic(address newMechanic) external;

    /// @notice Sets a new security council.
    /// @param newSecurityCouncil The address of the new security council.
    function setSecurityCouncil(address newSecurityCouncil) external;

    /// @notice Sets a new risk manager.
    /// @param newRiskManager The address of the new risk manager.
    function setRiskManager(address newRiskManager) external;

    /// @notice Sets a new risk manager timelock.
    /// @param newRiskManagerTimelock The address of the new risk manager timelock.
    function setRiskManagerTimelock(address newRiskManagerTimelock) external;

    /// @notice Sets the recovery mode.
    /// @param enabled True to enable recovery mode, false to disable it.
    function setRecoveryMode(bool enabled) external;

    /// @notice Sets the restricted accounting mode.
    /// @param enabled True to enable restricted accounting mode, false to disable it.
    function setRestrictedAccountingMode(bool enabled) external;

    /// @notice Adds a new accounting agent.
    /// @param newAgent The address of the new accounting agent.
    function addAccountingAgent(address newAgent) external;

    /// @notice Removes an accounting agent.
    /// @param agent The address of the accounting agent to remove.
    function removeAccountingAgent(address agent) external;
}
