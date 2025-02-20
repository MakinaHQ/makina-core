// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IBaseMakinaRegistry {
    event CaliberBeaconChange(address indexed oldCaliberBeacon, address indexed newCaliberBeacon);
    event OracleRegistryChange(address indexed oldOracleRegistry, address indexed newOracleRegistry);
    event SwapperChange(address indexed oldSwapper, address indexed newSwapper);

    /// @notice Address of the oracle registry.
    function oracleRegistry() external view returns (address);

    /// @notice Address of the swapper module.
    function swapper() external view returns (address);

    /// @notice Address of the caliber beacon contract.
    function caliberBeacon() external view returns (address);

    /// @notice Sets the oracle registry address.
    /// @param _oracleRegistry The oracle registry address.
    function setOracleRegistry(address _oracleRegistry) external;

    /// @notice Sets the swapper address.
    /// @param _swapper The swapper address.
    function setSwapper(address _swapper) external;

    /// @notice Sets the caliber beacon address.
    /// @param _caliberBeacon The caliber beacon address.
    function setCaliberBeacon(address _caliberBeacon) external;
}
