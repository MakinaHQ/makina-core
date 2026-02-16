// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IMakinaGovernable} from "../interfaces/IMakinaGovernable.sol";
import {Errors} from "../libraries/Errors.sol";

abstract contract MakinaGovernable is AccessManagedUpgradeable, IMakinaGovernable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:storage-location erc7201:makina.storage.MakinaGovernable
    struct MakinaGovernableStorage {
        address _mechanic;
        address _securityCouncil;
        address _riskManager;
        address _riskManagerTimelock;
        bool _recoveryMode;
        bool _restrictedAccountingMode;
        mapping(address user => bool isAccountingAgent) _isAccountingAgent;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.MakinaGovernable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MakinaGovernableStorageLocation =
        0x7e702089668346e906996be6de3dfc0cb2b0c125fc09b3c0391871825913e000;

    function _getMakinaGovernableStorage() internal pure returns (MakinaGovernableStorage storage $) {
        assembly {
            $.slot := MakinaGovernableStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function __MakinaGovernable_init(MakinaGovernableInitParams calldata params) internal onlyInitializing {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        $._mechanic = params.initialMechanic;
        $._securityCouncil = params.initialSecurityCouncil;
        $._riskManager = params.initialRiskManager;
        $._riskManagerTimelock = params.initialRiskManagerTimelock;
        $._restrictedAccountingMode = params.initialRestrictedAccountingMode;
        for (uint256 i; i < params.initialAccountingAgents.length; ++i) {
            _addAccountingAgent(params.initialAccountingAgents[i]);
        }
        __AccessManaged_init(params.initialAuthority);
    }

    modifier onlyOperator() {
        if (!isOperator(msg.sender)) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    modifier onlyMechanic() {
        if (msg.sender != _getMakinaGovernableStorage()._mechanic) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    modifier onlySecurityCouncil() {
        if (msg.sender != _getMakinaGovernableStorage()._securityCouncil) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    modifier onlyRiskManager() {
        if (msg.sender != _getMakinaGovernableStorage()._riskManager) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    modifier onlyRiskManagerTimelock() {
        if (msg.sender != _getMakinaGovernableStorage()._riskManagerTimelock) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    modifier notRecoveryMode() {
        if (_getMakinaGovernableStorage()._recoveryMode) {
            revert Errors.RecoveryMode();
        }
        _;
    }

    modifier onlyAccountingAuthorized() {
        if (!isAccountingAuthorized(msg.sender)) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    /// @inheritdoc IMakinaGovernable
    function mechanic() external view override returns (address) {
        return _getMakinaGovernableStorage()._mechanic;
    }

    /// @inheritdoc IMakinaGovernable
    function securityCouncil() public view override returns (address) {
        return _getMakinaGovernableStorage()._securityCouncil;
    }

    /// @inheritdoc IMakinaGovernable
    function riskManager() external view override returns (address) {
        return _getMakinaGovernableStorage()._riskManager;
    }

    /// @inheritdoc IMakinaGovernable
    function riskManagerTimelock() external view override returns (address) {
        return _getMakinaGovernableStorage()._riskManagerTimelock;
    }

    /// @inheritdoc IMakinaGovernable
    function recoveryMode() external view returns (bool) {
        return _getMakinaGovernableStorage()._recoveryMode;
    }

    /// @inheritdoc IMakinaGovernable
    function restrictedAccountingMode() external view override returns (bool) {
        return _getMakinaGovernableStorage()._restrictedAccountingMode;
    }

    /// @inheritdoc IMakinaGovernable
    function isAccountingAgent(address user) external view override returns (bool) {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        return user == $._mechanic || user == $._securityCouncil || $._isAccountingAgent[user];
    }

    /// @inheritdoc IMakinaGovernable
    function isOperator(address user) public view override returns (bool) {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        return user == ($._recoveryMode ? $._securityCouncil : $._mechanic);
    }

    /// @inheritdoc IMakinaGovernable
    function isAccountingAuthorized(address user) public view override returns (bool) {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        return (!$._recoveryMode && (!$._restrictedAccountingMode || user == $._mechanic || $._isAccountingAgent[user]))
            || user == $._securityCouncil;
    }

    /// @inheritdoc IMakinaGovernable
    function setMechanic(address newMechanic) external override restricted {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        emit MechanicChanged($._mechanic, newMechanic);
        $._mechanic = newMechanic;
    }

    /// @inheritdoc IMakinaGovernable
    function setSecurityCouncil(address newSecurityCouncil) external override restricted {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        emit SecurityCouncilChanged($._securityCouncil, newSecurityCouncil);
        $._securityCouncil = newSecurityCouncil;
    }

    /// @inheritdoc IMakinaGovernable
    function setRiskManager(address newRiskManager) external override restricted {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        emit RiskManagerChanged($._riskManager, newRiskManager);
        $._riskManager = newRiskManager;
    }

    /// @inheritdoc IMakinaGovernable
    function setRiskManagerTimelock(address newRiskManagerTimelock) external override restricted {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        emit RiskManagerTimelockChanged($._riskManagerTimelock, newRiskManagerTimelock);
        $._riskManagerTimelock = newRiskManagerTimelock;
    }

    /// @inheritdoc IMakinaGovernable
    function setRecoveryMode(bool enabled) external onlySecurityCouncil {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        if ($._recoveryMode != enabled) {
            $._recoveryMode = enabled;
            emit RecoveryModeChanged(enabled);
        }
    }

    /// @inheritdoc IMakinaGovernable
    function setRestrictedAccountingMode(bool enabled) external restricted {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        if ($._restrictedAccountingMode != enabled) {
            $._restrictedAccountingMode = enabled;
            emit RestrictedAccountingModeChanged(enabled);
        }
    }

    /// @inheritdoc IMakinaGovernable
    function addAccountingAgent(address newAgent) external override restricted {
        _addAccountingAgent(newAgent);
    }

    /// @inheritdoc IMakinaGovernable
    function removeAccountingAgent(address agent) external override restricted {
        _removeAccountingAgent(agent);
    }

    /// @dev Internal logic for adding an accounting agent.
    function _addAccountingAgent(address newAgent) internal {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        if (newAgent == $._mechanic || newAgent == $._securityCouncil || $._isAccountingAgent[newAgent]) {
            revert Errors.AlreadyAccountingAgent();
        }
        $._isAccountingAgent[newAgent] = true;
        emit AccountingAgentAdded(newAgent);
    }

    /// @dev Internal logic for removing an accounting agent.
    function _removeAccountingAgent(address agent) internal {
        MakinaGovernableStorage storage $ = _getMakinaGovernableStorage();
        if (agent == $._mechanic || agent == $._securityCouncil) {
            revert Errors.ProtectedAccountingAgent();
        }
        if (!$._isAccountingAgent[agent]) {
            revert Errors.NotAccountingAgent();
        }
        $._isAccountingAgent[agent] = false;
        emit AccountingAgentRemoved(agent);
    }
}
