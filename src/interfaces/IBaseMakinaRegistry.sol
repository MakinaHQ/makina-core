// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IBaseMakinaRegistry {
    event CaliberBeaconChange(address indexed oldCaliberBeacon, address indexed newCaliberBeacon);
    event OracleRegistryChange(address indexed oldOracleRegistry, address indexed newOracleRegistry);
    event SwapModuleChange(address indexed oldSwapModule, address indexed newSwapModule);
    event TokenRegistryChange(address indexed oldTokenRegistry, address indexed newTokenRegistry);

    /// @notice Address of the oracle registry.
    function oracleRegistry() external view returns (address);

    /// @notice Address of the token registry.
    function tokenRegistry() external view returns (address);

    /// @notice Address of the swapModule module.
    function swapModule() external view returns (address);

    /// @notice Address of the caliber beacon contract.
    function caliberBeacon() external view returns (address);

    /// @notice Sets the oracle registry address.
    /// @param _oracleRegistry The oracle registry address.
    function setOracleRegistry(address _oracleRegistry) external;

    /// @notice Sets the token registry address.
    /// @param _tokenRegistry The token registry address.
    function setTokenRegistry(address _tokenRegistry) external;

    /// @notice Sets the swapModule address.
    /// @param _swapModule The swapModule address.
    function setSwapModule(address _swapModule) external;

    /// @notice Sets the caliber beacon address.
    /// @param _caliberBeacon The caliber beacon address.
    function setCaliberBeacon(address _caliberBeacon) external;
}
