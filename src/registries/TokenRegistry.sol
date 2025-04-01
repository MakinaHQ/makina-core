// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {ITokenRegistry} from "../interfaces/ITokenRegistry.sol";

contract TokenRegistry is AccessManagedUpgradeable, ITokenRegistry {
    mapping(address localToken => mapping(uint256 foreignEvmChainId => address foreignToken)) private
        _localToForeignTokens;
    mapping(address foreignToken => mapping(uint256 foreignEvmChainId => address localToken)) private
        _foreignToLocalTokens;

    function initialize(address _accessManager) external initializer {
        __AccessManaged_init(_accessManager);
    }

    /// @inheritdoc ITokenRegistry
    function getForeignToken(address _localToken, uint256 _foreignEvmChainId) external view returns (address) {
        address foreignToken = _localToForeignTokens[_localToken][_foreignEvmChainId];
        if (foreignToken == address(0)) {
            revert ForeignTokenNotRegistered(_localToken, _foreignEvmChainId);
        }
        return foreignToken;
    }

    /// @inheritdoc ITokenRegistry
    function getLocalToken(address _foreignToken, uint256 _foreignEvmChainId) external view returns (address) {
        address localToken = _foreignToLocalTokens[_foreignToken][_foreignEvmChainId];
        if (localToken == address(0)) {
            revert LocalTokenNotRegistered(_foreignToken, _foreignEvmChainId);
        }
        return localToken;
    }

    /// @inheritdoc ITokenRegistry
    function setToken(address _localToken, uint256 _foreignEvmChainId, address _foreignToken) external restricted {
        if (_localToken == address(0) || _foreignToken == address(0)) {
            revert ZeroTokenAddress();
        }
        if (_foreignEvmChainId == 0) {
            revert ZeroChainId();
        }
        _localToForeignTokens[_localToken][_foreignEvmChainId] = _foreignToken;
        _foreignToLocalTokens[_foreignToken][_foreignEvmChainId] = _localToken;
        emit TokenRegistered(_localToken, _foreignEvmChainId, _foreignToken);
    }
}
