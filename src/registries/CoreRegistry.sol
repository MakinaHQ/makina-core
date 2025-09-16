// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {ICoreRegistry} from "../interfaces/ICoreRegistry.sol";

abstract contract CoreRegistry is AccessManagedUpgradeable, ICoreRegistry {
    /// @custom:storage-location erc7201:makina.storage.CoreRegistry
    struct CoreRegistryStorage {
        address _coreFactory;
        address _oracleRegistry;
        address _tokenRegistry;
        address _swapModule;
        address _flashLoanModule;
        address _caliberBeacon;
        mapping(uint16 => address) _bridgeAdapters;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.CoreRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CoreRegistryStorageLocation =
        0x12dc8e8f7173ac8c2e47b3781b91f41f03f310bb59e154cde6d484a5b5f20300;

    function _getCoreRegistryStorage() private pure returns (CoreRegistryStorage storage $) {
        assembly {
            $.slot := CoreRegistryStorageLocation
        }
    }

    function __CoreRegistry_init(address _oracleRegistry, address _tokenRegistry, address _initialAuthority)
        internal
        onlyInitializing
    {
        CoreRegistryStorage storage $ = _getCoreRegistryStorage();
        $._oracleRegistry = _oracleRegistry;
        $._tokenRegistry = _tokenRegistry;
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc ICoreRegistry
    function coreFactory() external view override returns (address) {
        return _getCoreRegistryStorage()._coreFactory;
    }

    /// @inheritdoc ICoreRegistry
    function oracleRegistry() external view override returns (address) {
        return _getCoreRegistryStorage()._oracleRegistry;
    }

    /// @inheritdoc ICoreRegistry
    function tokenRegistry() external view override returns (address) {
        return _getCoreRegistryStorage()._tokenRegistry;
    }

    /// @inheritdoc ICoreRegistry
    function swapModule() external view override returns (address) {
        return _getCoreRegistryStorage()._swapModule;
    }

    /// @inheritdoc ICoreRegistry
    function flashLoanModule() external view override returns (address) {
        return _getCoreRegistryStorage()._flashLoanModule;
    }

    /// @inheritdoc ICoreRegistry
    function caliberBeacon() external view override returns (address) {
        return _getCoreRegistryStorage()._caliberBeacon;
    }

    /// @inheritdoc ICoreRegistry
    function bridgeAdapterBeacon(uint16 bridgeId) external view override returns (address) {
        return _getCoreRegistryStorage()._bridgeAdapters[bridgeId];
    }

    /// @inheritdoc ICoreRegistry
    function setCoreFactory(address _coreFactory) external override restricted {
        CoreRegistryStorage storage $ = _getCoreRegistryStorage();
        emit CoreFactoryChanged($._coreFactory, _coreFactory);
        $._coreFactory = _coreFactory;
    }

    /// @inheritdoc ICoreRegistry
    function setOracleRegistry(address _oracleRegistry) external override restricted {
        CoreRegistryStorage storage $ = _getCoreRegistryStorage();
        emit OracleRegistryChanged($._oracleRegistry, _oracleRegistry);
        $._oracleRegistry = _oracleRegistry;
    }

    /// @inheritdoc ICoreRegistry
    function setTokenRegistry(address _tokenRegistry) external override restricted {
        CoreRegistryStorage storage $ = _getCoreRegistryStorage();
        emit TokenRegistryChanged($._tokenRegistry, _tokenRegistry);
        $._tokenRegistry = _tokenRegistry;
    }

    /// @inheritdoc ICoreRegistry
    function setSwapModule(address _swapModule) external override restricted {
        CoreRegistryStorage storage $ = _getCoreRegistryStorage();
        emit SwapModuleChanged($._swapModule, _swapModule);
        $._swapModule = _swapModule;
    }

    /// @inheritdoc ICoreRegistry
    function setFlashLoanModule(address _flashLoanModule) external restricted {
        CoreRegistryStorage storage $ = _getCoreRegistryStorage();
        emit FlashLoanModuleChanged($._flashLoanModule, _flashLoanModule);
        $._flashLoanModule = _flashLoanModule;
    }

    /// @inheritdoc ICoreRegistry
    function setCaliberBeacon(address _caliberBeacon) external override restricted {
        CoreRegistryStorage storage $ = _getCoreRegistryStorage();
        emit CaliberBeaconChanged($._caliberBeacon, _caliberBeacon);
        $._caliberBeacon = _caliberBeacon;
    }

    /// @inheritdoc ICoreRegistry
    function setBridgeAdapterBeacon(uint16 bridgeId, address _bridgeAdapter) external override restricted {
        CoreRegistryStorage storage $ = _getCoreRegistryStorage();
        emit BridgeAdapterBeaconChanged(uint256(bridgeId), $._bridgeAdapters[bridgeId], _bridgeAdapter);
        $._bridgeAdapters[bridgeId] = _bridgeAdapter;
    }
}
