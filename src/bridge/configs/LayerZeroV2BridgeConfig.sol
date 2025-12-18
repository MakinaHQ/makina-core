// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {IBridgeConfig} from "../../interfaces/IBridgeConfig.sol";
import {ILayerZeroV2BridgeConfig} from "../../interfaces/ILayerZeroV2BridgeConfig.sol";
import {Errors} from "../../libraries/Errors.sol";

contract LayerZeroV2BridgeConfig is AccessManagedUpgradeable, ILayerZeroV2BridgeConfig {
    /// @custom:storage-location erc7201:makina.storage.LayerZeroV2BridgeConfig
    struct LayerZeroV2BridgeConfigStorage {
        mapping(uint256 evmChainId => uint32 lzChainId) _evmToLzChainId;
        mapping(uint32 lzChainId => uint256 evmChainId) _lzToEvmChainId;
        mapping(address localToken => address oft) _tokenToOft;
        mapping(address localToken => mapping(uint256 foreignEvmChainId => address foreignToken)) _localToForeignTokens;
        mapping(address foreignToken => mapping(uint256 foreignEvmChainId => address localToken)) _foreignToLocalTokens;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.LayerZeroV2BridgeConfig")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LayerZeroV2BridgeConfigStorageLocation =
        0x9968c8893e7d72567bf0ce47e55989cd61e749404314ded743fba239bde60b00;

    function _getLayerZeroV2BridgeConfigStorage() private pure returns (LayerZeroV2BridgeConfigStorage storage $) {
        assembly {
            $.slot := LayerZeroV2BridgeConfigStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc IBridgeConfig
    function isRouteSupported(address inputToken, uint256 foreignChainId, address outputToken)
        external
        view
        override
        returns (bool)
    {
        LayerZeroV2BridgeConfigStorage storage $ = _getLayerZeroV2BridgeConfigStorage();
        return $._evmToLzChainId[foreignChainId] != 0 && $._tokenToOft[inputToken] != address(0)
            && $._localToForeignTokens[inputToken][foreignChainId] == outputToken;
    }

    /// @inheritdoc ILayerZeroV2BridgeConfig
    function evmToLzChainId(uint256 evmChainId) external view override returns (uint32) {
        uint32 lzChainId = _getLayerZeroV2BridgeConfigStorage()._evmToLzChainId[evmChainId];
        if (lzChainId == 0) {
            revert Errors.EvmChainIdNotRegistered(evmChainId);
        }
        return lzChainId;
    }

    /// @inheritdoc ILayerZeroV2BridgeConfig
    function lzToEvmChainId(uint32 lzChainId) external view override returns (uint256) {
        uint256 evmChainId = _getLayerZeroV2BridgeConfigStorage()._lzToEvmChainId[lzChainId];
        if (evmChainId == 0) {
            revert Errors.LzChainIdNotRegistered(lzChainId);
        }
        return evmChainId;
    }

    /// @inheritdoc ILayerZeroV2BridgeConfig
    function tokenToOft(address token) external view override returns (address) {
        address oft = _getLayerZeroV2BridgeConfigStorage()._tokenToOft[token];
        if (oft == address(0)) {
            revert Errors.OftNotRegistered(token);
        }
        return oft;
    }

    /// @inheritdoc ILayerZeroV2BridgeConfig
    function getForeignToken(address localToken, uint256 foreignEvmChainId) external view returns (address) {
        address foreignToken = _getLayerZeroV2BridgeConfigStorage()._localToForeignTokens[localToken][foreignEvmChainId];
        if (foreignToken == address(0)) {
            revert Errors.LzForeignTokenNotRegistered(localToken, foreignEvmChainId);
        }
        return foreignToken;
    }

    /// @inheritdoc ILayerZeroV2BridgeConfig
    function setLzChainId(uint256 evmChainId, uint32 lzChainId) external override restricted {
        LayerZeroV2BridgeConfigStorage storage $ = _getLayerZeroV2BridgeConfigStorage();

        if (evmChainId == 0 || lzChainId == 0) {
            revert Errors.ZeroChainId();
        }

        uint32 oldLz = $._evmToLzChainId[evmChainId];
        if (oldLz != 0) {
            delete $._lzToEvmChainId[oldLz];
        }

        uint256 oldEvm = $._lzToEvmChainId[lzChainId];
        if (oldEvm != 0) {
            delete $._evmToLzChainId[oldEvm];
        }

        $._evmToLzChainId[evmChainId] = lzChainId;
        $._lzToEvmChainId[lzChainId] = evmChainId;
        emit LzChainIdRegistered(evmChainId, lzChainId);
    }

    /// @inheritdoc ILayerZeroV2BridgeConfig
    function setOft(address oft) external override restricted {
        LayerZeroV2BridgeConfigStorage storage $ = _getLayerZeroV2BridgeConfigStorage();

        if (oft == address(0)) {
            revert Errors.ZeroOftAddress();
        }

        address _token = IOFT(oft).token();

        $._tokenToOft[_token] = oft;
        emit OftRegistered(oft, _token);
    }

    /// @inheritdoc ILayerZeroV2BridgeConfig
    function setForeignToken(address localToken, uint256 foreignEvmChainId, address foreignToken) external restricted {
        LayerZeroV2BridgeConfigStorage storage $ = _getLayerZeroV2BridgeConfigStorage();

        if (localToken == address(0) || foreignToken == address(0)) {
            revert Errors.ZeroTokenAddress();
        }
        if (foreignEvmChainId == 0) {
            revert Errors.ZeroChainId();
        }

        address oldForeignToken = $._localToForeignTokens[localToken][foreignEvmChainId];
        if (oldForeignToken != address(0)) {
            delete $._foreignToLocalTokens[oldForeignToken][foreignEvmChainId];
        }

        address oldLocalToken = $._foreignToLocalTokens[foreignToken][foreignEvmChainId];
        if (oldLocalToken != address(0)) {
            delete $._localToForeignTokens[oldLocalToken][foreignEvmChainId];
        }

        $._localToForeignTokens[localToken][foreignEvmChainId] = foreignToken;
        $._foreignToLocalTokens[foreignToken][foreignEvmChainId] = localToken;
        emit ForeignTokenRegistered(localToken, foreignEvmChainId, foreignToken);
    }
}
