// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IChainRegistry} from "../interfaces/IChainRegistry.sol";

contract ChainRegistry is AccessManagedUpgradeable, IChainRegistry {
    mapping(uint256 evmChainId => uint16 whChainId) public _evmToWhChainId;
    mapping(uint16 whChainId => uint256 evmChainId) public _whToEvmChainId;

    function initialize(address _accessManager) public initializer {
        __AccessManaged_init(_accessManager);
    }

    /// @inheritdoc IChainRegistry
    function evmToWhChainId(uint256 _evmChainId) external view override returns (uint16) {
        uint16 whChainId = _evmToWhChainId[_evmChainId];
        if (whChainId == 0) {
            revert ChainIdNotRegistered();
        }
        return whChainId;
    }

    /// @inheritdoc IChainRegistry
    function whToEvmChainId(uint16 _whChainId) external view override returns (uint256) {
        uint256 evmChainId = _whToEvmChainId[_whChainId];
        if (evmChainId == 0) {
            revert ChainIdNotRegistered();
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
    }
}
