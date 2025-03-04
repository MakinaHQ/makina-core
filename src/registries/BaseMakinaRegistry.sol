// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IBaseMakinaRegistry} from "../interfaces/IBaseMakinaRegistry.sol";

abstract contract BaseMakinaRegistry is AccessManagedUpgradeable, IBaseMakinaRegistry {
    /// @custom:storage-location erc7201:makina.storage.BaseMakinaRegistry
    struct BaseMakinaRegistryStorage {
        address _oracleRegistry;
        address _swapper;
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

    function __BaseMakinaRegistry_init(address _oracleRegistry, address _swapper, address _initialAuthority)
        internal
        onlyInitializing
    {
        BaseMakinaRegistryStorage storage $ = _getBaseMakinaRegistryStorage();
        $._oracleRegistry = _oracleRegistry;
        $._swapper = _swapper;
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc IBaseMakinaRegistry
    function oracleRegistry() public view override returns (address) {
        return _getBaseMakinaRegistryStorage()._oracleRegistry;
    }

    /// @inheritdoc IBaseMakinaRegistry
    function swapper() public view override returns (address) {
        return _getBaseMakinaRegistryStorage()._swapper;
    }

    /// @inheritdoc IBaseMakinaRegistry
    function caliberBeacon() public view override returns (address) {
        return _getBaseMakinaRegistryStorage()._caliberBeacon;
    }

    /// @inheritdoc IBaseMakinaRegistry
    function setOracleRegistry(address _oracleRegistry) external override restricted {
        BaseMakinaRegistryStorage storage $ = _getBaseMakinaRegistryStorage();
        emit OracleRegistryChange($._oracleRegistry, _oracleRegistry);
        $._oracleRegistry = _oracleRegistry;
    }

    /// @inheritdoc IBaseMakinaRegistry
    function setSwapper(address _swapper) external override restricted {
        BaseMakinaRegistryStorage storage $ = _getBaseMakinaRegistryStorage();
        emit SwapperChange($._swapper, _swapper);
        $._swapper = _swapper;
    }

    /// @inheritdoc IBaseMakinaRegistry
    function setCaliberBeacon(address _caliberBeacon) external override restricted {
        BaseMakinaRegistryStorage storage $ = _getBaseMakinaRegistryStorage();
        emit CaliberBeaconChange($._caliberBeacon, _caliberBeacon);
        $._caliberBeacon = _caliberBeacon;
    }
}
