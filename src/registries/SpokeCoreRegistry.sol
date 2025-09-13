// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CoreRegistry} from "./CoreRegistry.sol";
import {ISpokeCoreRegistry} from "../interfaces/ISpokeCoreRegistry.sol";

contract SpokeCoreRegistry is CoreRegistry, ISpokeCoreRegistry {
    /// @custom:storage-location erc7201:makina.storage.SpokeCoreRegistry
    struct SpokeCoreRegistryStorage {
        address _caliberMailboxBeacon;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.SpokeCoreRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SpokeCoreRegistryStorageLocation =
        0xbb04d69665b59d5499b254d643357a8f35f2bcb1c74ee39b02b1345680315500;

    function _getSpokeCoreRegistryStorage() private pure returns (SpokeCoreRegistryStorage storage $) {
        assembly {
            $.slot := SpokeCoreRegistryStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _oracleRegistry, address _tokenRegistry, address _initialAuthority)
        external
        initializer
    {
        __CoreRegistry_init(_oracleRegistry, _tokenRegistry, _initialAuthority);
    }

    /// @inheritdoc ISpokeCoreRegistry
    function caliberMailboxBeacon() external view override returns (address) {
        return _getSpokeCoreRegistryStorage()._caliberMailboxBeacon;
    }

    /// @inheritdoc ISpokeCoreRegistry
    function setCaliberMailboxBeacon(address _caliberMailboxBeacon) external override restricted {
        SpokeCoreRegistryStorage storage $ = _getSpokeCoreRegistryStorage();
        emit CaliberMailboxBeaconChanged($._caliberMailboxBeacon, _caliberMailboxBeacon);
        $._caliberMailboxBeacon = _caliberMailboxBeacon;
    }
}
