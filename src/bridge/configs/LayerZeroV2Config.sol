// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {IBridgeConfig} from "../../interfaces/IBridgeConfig.sol";
import {ILayerZeroV2Config} from "../../interfaces/ILayerZeroV2Config.sol";
import {Errors} from "../../libraries/Errors.sol";

contract LayerZeroV2Config is AccessManagedUpgradeable, ILayerZeroV2Config {
    /// @custom:storage-location erc7201:makina.storage.LayerZeroV2Config
    struct LayerZeroV2ConfigStorage {
        mapping(uint256 evmChainId => uint32 lzChainId) _evmToLzChainId;
        mapping(uint32 lzChainId => uint256 evmChainId) _lzToEvmChainId;
        mapping(address localToken => address oft) _tokenToOft;
        mapping(address localToken => mapping(uint256 foreignEvmChainId => address foreignToken)) _localToForeignTokens;
        mapping(address foreignToken => mapping(uint256 foreignEvmChainId => address localToken)) _foreignToLocalTokens;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.LayerZeroV2Config")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LayerZeroV2ConfigStorageLocation =
        0x62b4a2297a1f0b2eac7af44333e1cdce86a8dd2d696bfda8364c8a5fcc10e300;

    function _getLayerZeroV2ConfigStorage() private pure returns (LayerZeroV2ConfigStorage storage $) {
        assembly {
            $.slot := LayerZeroV2ConfigStorageLocation
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
        LayerZeroV2ConfigStorage storage $ = _getLayerZeroV2ConfigStorage();
        return $._evmToLzChainId[foreignChainId] != 0 && $._tokenToOft[inputToken] != address(0)
            && $._localToForeignTokens[inputToken][foreignChainId] == outputToken;
    }

    /// @inheritdoc ILayerZeroV2Config
    function evmToLzChainId(uint256 evmChainId) external view override returns (uint32) {
        uint32 lzChainId = _getLayerZeroV2ConfigStorage()._evmToLzChainId[evmChainId];
        if (lzChainId == 0) {
            revert Errors.EvmChainIdNotRegistered(evmChainId);
        }
        return lzChainId;
    }

    /// @inheritdoc ILayerZeroV2Config
    function lzToEvmChainId(uint32 lzChainId) external view override returns (uint256) {
        uint256 evmChainId = _getLayerZeroV2ConfigStorage()._lzToEvmChainId[lzChainId];
        if (evmChainId == 0) {
            revert Errors.LzChainIdNotRegistered(lzChainId);
        }
        return evmChainId;
    }

    /// @inheritdoc ILayerZeroV2Config
    function tokenToOft(address token) external view override returns (address) {
        address oft = _getLayerZeroV2ConfigStorage()._tokenToOft[token];
        if (oft == address(0)) {
            revert Errors.OftNotRegistered(token);
        }
        return oft;
    }

    /// @inheritdoc ILayerZeroV2Config
    function getForeignToken(address localToken, uint256 foreignEvmChainId) external view returns (address) {
        address foreignToken = _getLayerZeroV2ConfigStorage()._localToForeignTokens[localToken][foreignEvmChainId];
        if (foreignToken == address(0)) {
            revert Errors.LzForeignTokenNotRegistered(localToken, foreignEvmChainId);
        }
        return foreignToken;
    }

    /// @inheritdoc ILayerZeroV2Config
    function setLzChainId(uint256 evmChainId, uint32 lzChainId) external override restricted {
        LayerZeroV2ConfigStorage storage $ = _getLayerZeroV2ConfigStorage();

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

    /// @inheritdoc ILayerZeroV2Config
    function setOft(address oft) external override restricted {
        LayerZeroV2ConfigStorage storage $ = _getLayerZeroV2ConfigStorage();

        if (oft == address(0)) {
            revert Errors.ZeroOftAddress();
        }

        address _token = IOFT(oft).token();

        $._tokenToOft[_token] = oft;
        emit OftRegistered(oft, _token);
    }

    /// @inheritdoc ILayerZeroV2Config
    function setForeignToken(address localToken, uint256 foreignEvmChainId, address foreignToken) external restricted {
        LayerZeroV2ConfigStorage storage $ = _getLayerZeroV2ConfigStorage();

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
