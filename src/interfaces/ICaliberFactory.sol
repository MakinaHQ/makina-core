// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

interface ICaliberFactory {
    event CaliberDeployed(address indexed caliber);

    /// @notice The address of the Caliber beacon
    function caliberBeacon() external view returns (address);

    /// @notice The address of the CaliberInbox beacon
    function caliberInboxBeacon() external view returns (address);

    /// @notice Caliber => is a caliber deployed by this factory
    function isCaliber(address caliber) external view returns (bool);

    /// @notice deploys a new Caliber instance
    /// @param _hubMachine The address of the hub machine inbox
    /// @param _accountingToken The address of the accounting token
    /// @param _acountingTokenPosID The position ID of the accounting token
    /// @param _initialPositionStaleThreshold The position accounting staleness threshold
    /// @param _initialAllowedInstrRoot The root of the Merkle tree containing allowed instructions
    /// @param _initialTimelockDuration The duration of the Merkle tree root update timelock
    /// @param _initialMaxSwapLossBps The max allowed value loss (in basis point) when swapping a base token into another
    /// @param _initialMechanic The address of the initial mechanic
    /// @param _initialSecurityCouncil The address of the initial security council
    /// @return caliber The address of the deployed Caliber instance
    function deployCaliber(
        address _hubMachine,
        address _accountingToken,
        uint256 _acountingTokenPosID,
        uint256 _initialPositionStaleThreshold,
        bytes32 _initialAllowedInstrRoot,
        uint256 _initialTimelockDuration,
        uint256 _initialMaxSwapLossBps,
        address _initialMechanic,
        address _initialSecurityCouncil
    ) external returns (address caliber);
}
