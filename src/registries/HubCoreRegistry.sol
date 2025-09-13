// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CoreRegistry} from "./CoreRegistry.sol";
import {IHubCoreRegistry} from "../interfaces/IHubCoreRegistry.sol";

contract HubCoreRegistry is CoreRegistry, IHubCoreRegistry {
    /// @custom:storage-location erc7201:makina.storage.HubCoreRegistry
    struct HubCoreRegistryStorage {
        address _chainRegistry;
        address _machineBeacon;
        address _preDepositVaultBeacon;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.HubCoreRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HubCoreRegistryStorageLocation =
        0x662caa641f82b896df85da03edbf3b36c0e08aa64db68d7994394899aadc4700;

    function _getHubCoreRegistryStorage() private pure returns (HubCoreRegistryStorage storage $) {
        assembly {
            $.slot := HubCoreRegistryStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _oracleRegistry,
        address _tokenRegistry,
        address _chainRegistry,
        address _initialAuthority
    ) external initializer {
        _getHubCoreRegistryStorage()._chainRegistry = _chainRegistry;
        __CoreRegistry_init(_oracleRegistry, _tokenRegistry, _initialAuthority);
    }

    /// @inheritdoc IHubCoreRegistry
    function chainRegistry() external view override returns (address) {
        return _getHubCoreRegistryStorage()._chainRegistry;
    }

    /// @inheritdoc IHubCoreRegistry
    function machineBeacon() external view override returns (address) {
        return _getHubCoreRegistryStorage()._machineBeacon;
    }

    /// @inheritdoc IHubCoreRegistry
    function preDepositVaultBeacon() external view override returns (address) {
        return _getHubCoreRegistryStorage()._preDepositVaultBeacon;
    }

    /// @inheritdoc IHubCoreRegistry
    function setChainRegistry(address _chainRegistry) external override restricted {
        HubCoreRegistryStorage storage $ = _getHubCoreRegistryStorage();
        emit ChainRegistryChanged($._chainRegistry, _chainRegistry);
        $._chainRegistry = _chainRegistry;
    }

    /// @inheritdoc IHubCoreRegistry
    function setMachineBeacon(address _machineBeacon) external override restricted {
        HubCoreRegistryStorage storage $ = _getHubCoreRegistryStorage();
        emit MachineBeaconChanged($._machineBeacon, _machineBeacon);
        $._machineBeacon = _machineBeacon;
    }

    /// @inheritdoc IHubCoreRegistry
    function setPreDepositVaultBeacon(address _preDepositVaultBeacon) external override restricted {
        HubCoreRegistryStorage storage $ = _getHubCoreRegistryStorage();
        emit PreDepositVaultBeaconChanged($._preDepositVaultBeacon, _preDepositVaultBeacon);
        $._preDepositVaultBeacon = _preDepositVaultBeacon;
    }
}
