// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {ITokenRegistry} from "../interfaces/ITokenRegistry.sol";
import {Errors} from "../libraries/Errors.sol";

contract TokenRegistry is AccessManagedUpgradeable, ITokenRegistry {
    /// @custom:storage-location erc7201:makina.storage.TokenRegistry
    struct TokenRegistryStorage {
        mapping(address localToken => mapping(uint256 foreignEvmChainId => address foreignToken)) _localToForeignTokens;
        mapping(address foreignToken => mapping(uint256 foreignEvmChainId => address localToken)) _foreignToLocalTokens;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.TokenRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TokenRegistryStorageLocation =
        0x1aeafc547075d7f69f86c9a87aafb3edc5a48d01acbbe220b9a330d69702ed00;

    function _getTokenRegistryStorage() private pure returns (TokenRegistryStorage storage $) {
        assembly {
            $.slot := TokenRegistryStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _accessManager) external initializer {
        __AccessManaged_init(_accessManager);
    }

    /// @inheritdoc ITokenRegistry
    function getForeignToken(address _localToken, uint256 _foreignEvmChainId) external view returns (address) {
        address foreignToken = _getTokenRegistryStorage()._localToForeignTokens[_localToken][_foreignEvmChainId];
        if (foreignToken == address(0)) {
            revert Errors.ForeignTokenNotRegistered(_localToken, _foreignEvmChainId);
        }
        return foreignToken;
    }

    /// @inheritdoc ITokenRegistry
    function getLocalToken(address _foreignToken, uint256 _foreignEvmChainId) external view returns (address) {
        address localToken = _getTokenRegistryStorage()._foreignToLocalTokens[_foreignToken][_foreignEvmChainId];
        if (localToken == address(0)) {
            revert Errors.LocalTokenNotRegistered(_foreignToken, _foreignEvmChainId);
        }
        return localToken;
    }

    /// @inheritdoc ITokenRegistry
    function setToken(address _localToken, uint256 _foreignEvmChainId, address _foreignToken) external restricted {
        TokenRegistryStorage storage $ = _getTokenRegistryStorage();

        if (_localToken == address(0) || _foreignToken == address(0)) {
            revert Errors.ZeroTokenAddress();
        }
        if (_foreignEvmChainId == 0) {
            revert Errors.ZeroChainId();
        }

        address oldForeignToken = $._localToForeignTokens[_localToken][_foreignEvmChainId];
        if (oldForeignToken != address(0)) {
            delete $._foreignToLocalTokens[oldForeignToken][_foreignEvmChainId];
        }

        address oldLocalToken = $._foreignToLocalTokens[_foreignToken][_foreignEvmChainId];
        if (oldLocalToken != address(0)) {
            delete $._localToForeignTokens[oldLocalToken][_foreignEvmChainId];
        }

        $._localToForeignTokens[_localToken][_foreignEvmChainId] = _foreignToken;
        $._foreignToLocalTokens[_foreignToken][_foreignEvmChainId] = _localToken;
        emit TokenRegistered(_localToken, _foreignEvmChainId, _foreignToken);
    }
}
