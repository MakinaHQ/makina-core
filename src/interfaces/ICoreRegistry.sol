// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ICoreRegistry {
    event BridgeAdapterBeaconChanged(
        uint256 indexed bridgeId, address indexed oldBridgeAdapterBeacon, address indexed newBridgeAdapterBeacon
    );
    event CaliberBeaconChanged(address indexed oldCaliberBeacon, address indexed newCaliberBeacon);
    event CoreFactoryChanged(address indexed oldCoreFactory, address indexed newCoreFactory);
    event FlashLoanModuleChanged(address indexed oldFlashLoanModule, address indexed newFlashLoanModule);
    event OracleRegistryChanged(address indexed oldOracleRegistry, address indexed newOracleRegistry);
    event SwapModuleChanged(address indexed oldSwapModule, address indexed newSwapModule);
    event TokenRegistryChanged(address indexed oldTokenRegistry, address indexed newTokenRegistry);

    /// @notice Address of the core factory.
    function coreFactory() external view returns (address);

    /// @notice Address of the oracle registry.
    function oracleRegistry() external view returns (address);

    /// @notice Address of the token registry.
    function tokenRegistry() external view returns (address);

    /// @notice Address of the swapModule module.
    function swapModule() external view returns (address);

    /// @notice Address of the flashLoan module.
    function flashLoanModule() external view returns (address);

    /// @notice Address of the caliber beacon contract.
    function caliberBeacon() external view returns (address);

    /// @notice Bridge ID => Address of the bridge adapter beacon contract.
    function bridgeAdapterBeacon(uint16 bridgeId) external view returns (address);

    /// @notice Sets the core factory address.
    /// @param _coreFactory The core factory address.
    function setCoreFactory(address _coreFactory) external;

    /// @notice Sets the oracle registry address.
    /// @param _oracleRegistry The oracle registry address.
    function setOracleRegistry(address _oracleRegistry) external;

    /// @notice Sets the token registry address.
    /// @param _tokenRegistry The token registry address.
    function setTokenRegistry(address _tokenRegistry) external;

    /// @notice Sets the swap module address.
    /// @param _swapModule The swapModule address.
    function setSwapModule(address _swapModule) external;

    /// @notice Sets the flashLoan module address.
    /// @param _flashLoanModule The flashLoan module address.
    function setFlashLoanModule(address _flashLoanModule) external;

    /// @notice Sets the caliber beacon address.
    /// @param _caliberBeacon The caliber beacon address.
    function setCaliberBeacon(address _caliberBeacon) external;

    /// @notice Sets the bridge adapter beacon address.
    /// @param bridgeId The bridge ID.
    /// @param _bridgeAdapter The bridge adapter beacon address.
    function setBridgeAdapterBeacon(uint16 bridgeId, address _bridgeAdapter) external;
}
