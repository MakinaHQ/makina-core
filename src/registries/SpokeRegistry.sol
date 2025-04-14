// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseMakinaRegistry} from "./BaseMakinaRegistry.sol";
import {ISpokeRegistry} from "../interfaces/ISpokeRegistry.sol";

contract SpokeRegistry is BaseMakinaRegistry, ISpokeRegistry {
    /// @custom:storage-location erc7201:makina.storage.SpokeRegistry
    struct SpokeRegistryStorage {
        address _caliberMailboxBeacon;
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

    function initialize(address _oracleRegistry, address _tokenRegistry, address _swapModule, address _initialAuthority)
        external
        initializer
    {
        __BaseMakinaRegistry_init(_oracleRegistry, _tokenRegistry, _swapModule, _initialAuthority);
    }

    /// @inheritdoc ISpokeRegistry
    function caliberMailboxBeacon() external view override returns (address) {
        return _getSpokeRegistryStorage()._caliberMailboxBeacon;
    }

    /// @inheritdoc ISpokeRegistry
    function setCaliberMailboxBeacon(address _caliberMailboxBeacon) external override restricted {
        SpokeRegistryStorage storage $ = _getSpokeRegistryStorage();
        emit CaliberMailboxBeaconChange($._caliberMailboxBeacon, _caliberMailboxBeacon);
        $._caliberMailboxBeacon = _caliberMailboxBeacon;
    }
}
