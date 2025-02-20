// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseMakinaRegistry} from "./BaseMakinaRegistry.sol";
import {ISpokeRegistry} from "../interfaces/ISpokeRegistry.sol";

contract SpokeRegistry is BaseMakinaRegistry, ISpokeRegistry {
    /// @custom:storage-location erc7201:makina.storage.SpokeRegistry
    struct SpokeRegistryStorage {
        address _caliberFactory;
        address _spokeCaliberMailboxBeacon;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.SpokeRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SpokeRegistryStorageLocation =
        0xbc0e450e5c56c309b2a5348abbd93695f5540d6891d98bbf8de7febc09b8fb00;

    function _getSpokeRegistryStorage() private pure returns (SpokeRegistryStorage storage $) {
        assembly {
            $.slot := SpokeRegistryStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address oracleRegistry, address swapper, address initialAuthority) external initializer {
        __BaseMakinaRegistry_init(oracleRegistry, swapper, initialAuthority);
    }

    /// @inheritdoc ISpokeRegistry
    function caliberFactory() public view override returns (address) {
        return _getSpokeRegistryStorage()._caliberFactory;
    }

    /// @inheritdoc ISpokeRegistry
    function spokeCaliberMailboxBeacon() public view override returns (address) {
        return _getSpokeRegistryStorage()._spokeCaliberMailboxBeacon;
    }

    /// @inheritdoc ISpokeRegistry
    function setSpokeCaliberMailboxBeacon(address _spokeCaliberMailboxBeacon) external override restricted {
        SpokeRegistryStorage storage $ = _getSpokeRegistryStorage();
        emit SpokeCaliberMailboxBeaconChange($._spokeCaliberMailboxBeacon, _spokeCaliberMailboxBeacon);
        $._spokeCaliberMailboxBeacon = _spokeCaliberMailboxBeacon;
    }

    /// @inheritdoc ISpokeRegistry
    function setCaliberFactory(address _caliberFactory) external override restricted {
        SpokeRegistryStorage storage $ = _getSpokeRegistryStorage();
        emit CaliberFactoryChange($._caliberFactory, _caliberFactory);
        $._caliberFactory = _caliberFactory;
    }
}
