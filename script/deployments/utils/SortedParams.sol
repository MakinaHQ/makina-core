// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract SortedParams {
    struct PreDepositVaultInitParamsSorted {
        address initialAuthority;
        address initialRiskManager;
        uint256 initialShareLimit;
        bool initialWhitelistMode;
    }

    struct MachineInitParamsSorted {
        uint256 initialCaliberStaleThreshold;
        address initialDepositor;
        address initialFeeManager;
        uint256 initialFeeMintCooldown;
        uint256 initialMaxFixedFeeAccrualRate;
        uint256 initialMaxPerfFeeAccrualRate;
        address initialRedeemer;
        uint256 initialShareLimit;
    }

    struct CaliberInitParamsSorted {
        bytes32 initialAllowedInstrRoot;
        uint256 initialCooldownDuration;
        uint256 initialMaxPositionDecreaseLossBps;
        uint256 initialMaxPositionIncreaseLossBps;
        uint256 initialMaxSwapLossBps;
        uint256 initialPositionStaleThreshold;
        uint256 initialTimelockDuration;
    }

    struct MakinaGovernableInitParamsSorted {
        address initialAuthority;
        address initialMechanic;
        address initialRiskManager;
        address initialRiskManagerTimelock;
        address initialSecurityCouncil;
    }

    struct TimelockControllerInitParamsSorted {
        address initialAdmin;
        address[] initialExecutors;
        uint256 initialMinDelay;
        address[] initialProposers;
    }
}
