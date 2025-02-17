// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ICaliberFactory {
    error NotMachine();

    event CaliberDeployed(address indexed caliber);

    /// @notice Parameters for deploying a new Caliber instance.
    /// @param hubMachineEndpoint The address of the hub machine endpoint.
    /// @param accountingToken The address of the accounting token.
    /// @param accountingTokenPosId The position ID of the accounting token.
    /// @param initialPositionStaleThreshold The position accounting staleness threshold.
    /// @param initialAllowedInstrRoot The root of the Merkle tree containing allowed instructions.
    /// @param initialTimelockDuration The duration of the Merkle tree root update timelock.
    /// @param initialMaxPositionIncreaseLossBps The max allowed value loss (in basis point) when increasing a position.
    /// @param initialMaxPositionDecreaseLossBps The max allowed value loss (in basis point) when decreasing a position.
    /// @param initialMaxSwapLossBps The max allowed value loss (in basis point) when swapping a base token into another.
    /// @param initialMechanic The address of the initial mechanic.
    /// @param initialSecurityCouncil The address of the initial security council.
    /// @param initialAuthority The address of the initial authority.
    /// @return caliber The address of the deployed Caliber instance.
    struct CaliberDeployParams {
        address hubMachineEndpoint;
        address accountingToken;
        uint256 accountingTokenPosId;
        uint256 initialPositionStaleThreshold;
        bytes32 initialAllowedInstrRoot;
        uint256 initialTimelockDuration;
        uint256 initialMaxPositionIncreaseLossBps;
        uint256 initialMaxPositionDecreaseLossBps;
        uint256 initialMaxSwapLossBps;
        address initialMechanic;
        address initialSecurityCouncil;
        address initialAuthority;
    }

    /// @notice Address of the Makina registry.
    function registry() external view returns (address);

    /// @notice Caliber => Is a caliber deployed by this factory
    function isCaliber(address caliber) external view returns (bool);

    /// @notice Deploys a new Caliber instance.
    /// @param params The deployment parameters.
    function deployCaliber(CaliberDeployParams calldata params) external returns (address caliber);
}
