// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IChainRegistry} from "../interfaces/IChainRegistry.sol";
import {Errors} from "../libraries/Errors.sol";

contract ChainRegistry is AccessManagedUpgradeable, IChainRegistry {
    /// @custom:storage-location erc7201:makina.storage.ChainRegistry
    struct ChainRegistryStorage {
        mapping(uint256 evmChainId => uint16 whChainId) _evmToWhChainId;
        mapping(uint16 whChainId => uint256 evmChainId) _whToEvmChainId;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.ChainRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ChainRegistryStorageLocation =
        0x1fbdc0014f4c06b2b0ff2477b8b323f2857bce3cafc75fb45bc5110cee080300;

    function _getChainRegistryStorage() private pure returns (ChainRegistryStorage storage $) {
        assembly {
            $.slot := ChainRegistryStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority) external initializer {
        __AccessManaged_init(initialAuthority);
    }

    /// @inheritdoc IChainRegistry
    function isEvmChainIdRegistered(uint256 evmChainId) external view override returns (bool) {
        return _getChainRegistryStorage()._evmToWhChainId[evmChainId] != 0;
    }

    /// @inheritdoc IChainRegistry
    function isWhChainIdRegistered(uint16 whChainId) external view override returns (bool) {
        return _getChainRegistryStorage()._whToEvmChainId[whChainId] != 0;
    }

    /// @inheritdoc IChainRegistry
    function evmToWhChainId(uint256 evmChainId) external view override returns (uint16) {
        uint16 whChainId = _getChainRegistryStorage()._evmToWhChainId[evmChainId];
        if (whChainId == 0) {
            revert Errors.EvmChainIdNotRegistered(evmChainId);
        }
        return whChainId;
    }

    /// @inheritdoc IChainRegistry
    function whToEvmChainId(uint16 whChainId) external view override returns (uint256) {
        uint256 evmChainId = _getChainRegistryStorage()._whToEvmChainId[whChainId];
        if (evmChainId == 0) {
            revert Errors.WhChainIdNotRegistered(whChainId);
        }
        return evmChainId;
    }

    /// @inheritdoc IChainRegistry
    function setChainIds(uint256 evmChainId, uint16 whChainId) external restricted {
        ChainRegistryStorage storage $ = _getChainRegistryStorage();

        if (evmChainId == 0 || whChainId == 0) {
            revert Errors.ZeroChainId();
        }

        uint16 oldWh = $._evmToWhChainId[evmChainId];
        if (oldWh != 0) {
            delete $._whToEvmChainId[oldWh];
        }

        uint256 oldEvm = $._whToEvmChainId[whChainId];
        if (oldEvm != 0) {
            delete $._evmToWhChainId[oldEvm];
        }

        $._evmToWhChainId[evmChainId] = whChainId;
        $._whToEvmChainId[whChainId] = evmChainId;
        emit ChainIdsRegistered(evmChainId, whChainId);
    }
}
