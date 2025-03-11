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
        address _hubDualMailboxBeacon;
        address _spokeMachineMailboxBeacon;
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

    function initialize(address oracleRegistry, address swapper, address initialAuthority) external initializer {
        __BaseMakinaRegistry_init(oracleRegistry, swapper, initialAuthority);
    }

    /// @inheritdoc IHubRegistry
    function chainRegistry() public view override returns (address) {
        return _getHubRegistryStorage()._chainRegistry;
    }

    /// @inheritdoc IHubRegistry
    function machineFactory() public view override returns (address) {
        return _getHubRegistryStorage()._machineFactory;
    }

    /// @inheritdoc IHubRegistry
    function machineBeacon() public view override returns (address) {
        return _getHubRegistryStorage()._machineBeacon;
    }

    /// @inheritdoc IHubRegistry
    function hubDualMailboxBeacon() public view override returns (address) {
        return _getHubRegistryStorage()._hubDualMailboxBeacon;
    }

    /// @inheritdoc IHubRegistry
    function spokeMachineMailboxBeacon() public view override returns (address) {
        return _getHubRegistryStorage()._spokeMachineMailboxBeacon;
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

    /// @inheritdoc IHubRegistry
    function setHubDualMailboxBeacon(address _hubDualMailboxBeacon) external override restricted {
        HubRegistryStorage storage $ = _getHubRegistryStorage();
        emit HubDualMailboxBeaconChange($._hubDualMailboxBeacon, _hubDualMailboxBeacon);
        $._hubDualMailboxBeacon = _hubDualMailboxBeacon;
    }

    /// @inheritdoc IHubRegistry
    function setSpokeMachineMailboxBeacon(address _spokeMachineMailboxBeacon) external override restricted {
        HubRegistryStorage storage $ = _getHubRegistryStorage();
        emit SpokeMachineMailboxBeaconChange($._spokeMachineMailboxBeacon, _spokeMachineMailboxBeacon);
        $._spokeMachineMailboxBeacon = _spokeMachineMailboxBeacon;
    }
}
