// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

interface ICaliberFactory {
    event CaliberDeployed(address indexed caliber);

    /// @notice Address of the Makina registry.
    function registry() external view returns (address);

    /// @notice Caliber => Is a caliber deployed by this factory
    function isCaliber(address caliber) external view returns (bool);

    /// @notice Deploys a new Caliber instance.
    /// @param hubMachineInbox The address of the hub machine inbox.
    /// @param accountingToken The address of the accounting token.
    /// @param accountingTokenPosId The position ID of the accounting token.
    /// @param initialPositionStaleThreshold The position accounting staleness threshold.
    /// @param initialAllowedInstrRoot The root of the Merkle tree containing allowed instructions.
    /// @param initialTimelockDuration The duration of the Merkle tree root update timelock.
    /// @param initialMaxMgmtLossBps The max allowed value loss (in basis point) when managing a position.
    /// @param initialMaxSwapLossBps The max allowed value loss (in basis point) when swapping a base token into another.
    /// @param initialMechanic The address of the initial mechanic.
    /// @param initialSecurityCouncil The address of the initial security council.
    /// @return caliber The address of the deployed Caliber instance.
    function deployCaliber(
        address hubMachineInbox,
        address accountingToken,
        uint256 accountingTokenPosId,
        uint256 initialPositionStaleThreshold,
        bytes32 initialAllowedInstrRoot,
        uint256 initialTimelockDuration,
        uint256 initialMaxMgmtLossBps,
        uint256 initialMaxSwapLossBps,
        address initialMechanic,
        address initialSecurityCouncil
    ) external returns (address caliber);
}
