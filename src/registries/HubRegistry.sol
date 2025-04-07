// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseMakinaRegistry} from "./BaseMakinaRegistry.sol";
import {IHubRegistry} from "../interfaces/IHubRegistry.sol";

contract HubRegistry is BaseMakinaRegistry, IHubRegistry {
    /// @custom:storage-location erc7201:makina.storage.HubRegistry
    struct HubRegistryStorage {
        address _chainRegistry;
        address _machineFactory;
        address _machineBeacon;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.HubRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HubRegistryStorageLocation =
        0x457401123b2f0ea45aff737762ab0888ccf6c6721c405afcefc39e6970aa6e00;

    function _getHubRegistryStorage() private pure returns (HubRegistryStorage storage $) {
        assembly {
            $.slot := HubRegistryStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _oracleRegistry,
        address _tokenRegistry,
        address _chainRegistry,
        address _swapModule,
        address _initialAuthority
    ) external initializer {
        _getHubRegistryStorage()._chainRegistry = _chainRegistry;
        __BaseMakinaRegistry_init(_oracleRegistry, _tokenRegistry, _swapModule, _initialAuthority);
    }

    /// @inheritdoc IHubRegistry
    function chainRegistry() external view override returns (address) {
        return _getHubRegistryStorage()._chainRegistry;
    }

    /// @inheritdoc IHubRegistry
    function machineFactory() external view override returns (address) {
        return _getHubRegistryStorage()._machineFactory;
    }

    /// @inheritdoc IHubRegistry
    function machineBeacon() external view override returns (address) {
        return _getHubRegistryStorage()._machineBeacon;
    }

    /// @inheritdoc IHubRegistry
    function setChainRegistry(address _chainRegistry) external override restricted {
        HubRegistryStorage storage $ = _getHubRegistryStorage();
        emit ChainRegistryChange($._chainRegistry, _chainRegistry);
        $._chainRegistry = _chainRegistry;
    }

    /// @inheritdoc IHubRegistry
    function setMachineFactory(address _machineFactory) external override restricted {
        HubRegistryStorage storage $ = _getHubRegistryStorage();
        emit MachineFactoryChange($._machineFactory, _machineFactory);
        $._machineFactory = _machineFactory;
    }

    /// @inheritdoc IHubRegistry
    function setMachineBeacon(address _machineBeacon) external override restricted {
        HubRegistryStorage storage $ = _getHubRegistryStorage();
        emit MachineBeaconChange($._machineBeacon, _machineBeacon);
        $._machineBeacon = _machineBeacon;
    }
}
