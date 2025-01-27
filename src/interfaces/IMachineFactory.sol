// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IMachineFactory {
    event MachineDeployed(address indexed machine);

    /// @notice Address of the registry.
    function registry() external view returns (address);

    /// @notice Machine => whether the machine was deployed by this factory
    function isMachine(address machine) external view returns (bool);

    /// @notice Deploys a new Machine instance.
    /// @param _accountingToken The address of the accounting token.
    /// @param _initialMechanic The address of the initial mechanic.
    /// @param _initialSecurityCouncil The address of the initial security council.
    /// @param _initialAuthority The address of the initial authority.
    /// @param _initialCaliberStaleThreshold The caliber accounting staleness threshold in seconds.
    /// @param _hubCaliberAccountingTokenPosID The position ID of the hub caliber's accounting token.
    /// @param _hubCaliberPosStaleThreshold The hub caliber's position accounting staleness threshold.
    /// @param _hubCaliberAllowedInstrRoot The root of the Merkle tree containing allowed caliber instructions.
    /// @param _hubCaliberTimelockDuration The duration of the hub caliber's Merkle tree root update timelock.
    /// @param _hubCaliberMaxMgmtLossBps The max allowed value loss (in basis point) in the hub caliber when managing a position.
    /// @param _hubCaliberMaxSwapLossBps The max allowed value loss (in basis point) when swapping a base token into another in the hub caliber.
    /// @return machine The address of the deployed Machine instance.
    function deployMachine(
        address _accountingToken,
        address _initialMechanic,
        address _initialSecurityCouncil,
        address _initialAuthority,
        uint256 _initialCaliberStaleThreshold,
        uint256 _hubCaliberAccountingTokenPosID,
        uint256 _hubCaliberPosStaleThreshold,
        bytes32 _hubCaliberAllowedInstrRoot,
        uint256 _hubCaliberTimelockDuration,
        uint256 _hubCaliberMaxMgmtLossBps,
        uint256 _hubCaliberMaxSwapLossBps
    ) external returns (address machine);
}
