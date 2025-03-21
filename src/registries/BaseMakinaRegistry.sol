// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IBaseMakinaRegistry} from "../interfaces/IBaseMakinaRegistry.sol";

abstract contract BaseMakinaRegistry is AccessManagedUpgradeable, IBaseMakinaRegistry {
    /// @custom:storage-location erc7201:makina.storage.BaseMakinaRegistry
    struct BaseMakinaRegistryStorage {
        address _oracleRegistry;
        address _swapModule;
        address _caliberFactory;
        address _caliberBeacon;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.BaseMakinaRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseMakinaRegistryStorageLocation =
        0xf387cf56e96c92822f28ada2ef15bdd9e8f7ecfa43049586d78424bf258c8000;

    function _getBaseMakinaRegistryStorage() private pure returns (BaseMakinaRegistryStorage storage $) {
        assembly {
            $.slot := BaseMakinaRegistryStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function __BaseMakinaRegistry_init(address _oracleRegistry, address _swapModule, address _initialAuthority)
        internal
        onlyInitializing
    {
        BaseMakinaRegistryStorage storage $ = _getBaseMakinaRegistryStorage();
        $._oracleRegistry = _oracleRegistry;
        $._swapModule = _swapModule;
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc IBaseMakinaRegistry
    function oracleRegistry() external view override returns (address) {
        return _getBaseMakinaRegistryStorage()._oracleRegistry;
    }

    /// @inheritdoc IBaseMakinaRegistry
    function swapModule() external view override returns (address) {
        return _getBaseMakinaRegistryStorage()._swapModule;
    }

    /// @inheritdoc IBaseMakinaRegistry
    function caliberBeacon() external view override returns (address) {
        return _getBaseMakinaRegistryStorage()._caliberBeacon;
    }

    /// @inheritdoc IBaseMakinaRegistry
    function setOracleRegistry(address _oracleRegistry) external override restricted {
        BaseMakinaRegistryStorage storage $ = _getBaseMakinaRegistryStorage();
        emit OracleRegistryChange($._oracleRegistry, _oracleRegistry);
        $._oracleRegistry = _oracleRegistry;
    }

    /// @inheritdoc IBaseMakinaRegistry
    function setSwapModule(address _swapModule) external override restricted {
        BaseMakinaRegistryStorage storage $ = _getBaseMakinaRegistryStorage();
        emit SwapModuleChange($._swapModule, _swapModule);
        $._swapModule = _swapModule;
    }

    /// @inheritdoc IBaseMakinaRegistry
    function setCaliberBeacon(address _caliberBeacon) external override restricted {
        BaseMakinaRegistryStorage storage $ = _getBaseMakinaRegistryStorage();
        emit CaliberBeaconChange($._caliberBeacon, _caliberBeacon);
        $._caliberBeacon = _caliberBeacon;
    }
}
