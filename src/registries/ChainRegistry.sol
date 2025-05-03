// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IChainRegistry} from "../interfaces/IChainRegistry.sol";

contract ChainRegistry is AccessManagedUpgradeable, IChainRegistry {
    mapping(uint256 evmChainId => uint16 whChainId) private _evmToWhChainId;
    mapping(uint16 whChainId => uint256 evmChainId) private _whToEvmChainId;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _accessManager) external initializer {
        __AccessManaged_init(_accessManager);
    }

    /// @inheritdoc IChainRegistry
    function isEvmChainIdRegistered(uint256 _evmChainId) external view override returns (bool) {
        return _evmToWhChainId[_evmChainId] != 0;
    }

    /// @inheritdoc IChainRegistry
    function isWhChainIdRegistered(uint16 _whChainId) external view override returns (bool) {
        return _whToEvmChainId[_whChainId] != 0;
    }

    /// @inheritdoc IChainRegistry
    function evmToWhChainId(uint256 _evmChainId) external view override returns (uint16) {
        uint16 whChainId = _evmToWhChainId[_evmChainId];
        if (whChainId == 0) {
            revert EvmChainIdNotRegistered(_evmChainId);
        }
        return whChainId;
    }

    /// @inheritdoc IChainRegistry
    function whToEvmChainId(uint16 _whChainId) external view override returns (uint256) {
        uint256 evmChainId = _whToEvmChainId[_whChainId];
        if (evmChainId == 0) {
            revert WhChainIdNotRegistered(_whChainId);
        }
        return evmChainId;
    }

    /// @inheritdoc IChainRegistry
    function setChainIds(uint256 _evmChainId, uint16 _whChainId) external restricted {
        if (_evmChainId == 0 || _whChainId == 0) {
            revert ZeroChainId();
        }
        _evmToWhChainId[_evmChainId] = _whChainId;
        _whToEvmChainId[_whChainId] = _evmChainId;
        emit ChainIdsRegistered(_evmChainId, _whChainId);
    }
}
