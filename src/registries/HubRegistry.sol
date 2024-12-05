// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {BaseMakinaRegistry} from "./BaseMakinaRegistry.sol";
import {IHubRegistry} from "../interfaces/IHubRegistry.sol";

contract HubRegistry is BaseMakinaRegistry, IHubRegistry {
    /// @custom:storage-location erc7201:makina.storage.HubRegistry
    struct HubRegistryStorage {
        address _machineFactory;
        address _machineBeacon;
        address _machineHubInboxBeacon;
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

    function initialize(initParams calldata params) external initializer {
        __BaseMakinaRegistry_init(params.oracleRegistry, params.swapper, params.initialAuthority);
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
    function machineHubInboxBeacon() public view override returns (address) {
        return _getHubRegistryStorage()._machineHubInboxBeacon;
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
    function setMachineHubInboxBeacon(address _machineHubInboxBeacon) external override restricted {
        HubRegistryStorage storage $ = _getHubRegistryStorage();
        emit MachineHubInboxBeaconChange($._machineHubInboxBeacon, _machineHubInboxBeacon);
        $._machineHubInboxBeacon = _machineHubInboxBeacon;
    }
}
