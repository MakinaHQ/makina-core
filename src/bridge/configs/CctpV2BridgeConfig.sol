// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {ICctpV2BridgeConfig} from "../../interfaces/ICctpV2BridgeConfig.sol";
import {IBridgeConfig} from "../../interfaces/IBridgeConfig.sol";
import {Errors} from "../../libraries/Errors.sol";

contract CctpV2BridgeConfig is AccessManagedUpgradeable, ICctpV2BridgeConfig {
    uint256 private constant MAINNET_CHAIN_ID = 1;
    uint32 private constant MAINNET_CCTP_DOMAIN = 0;

    /// @custom:storage-location erc7201:makina.storage.CctpV2BridgeConfig
    struct CctpV2BridgeConfigStorage {
        mapping(uint256 evmChainId => uint32 cctpDomain) _evmToCctpId;
        mapping(uint32 cctpDomain => uint256 evmChainId) _cctpToEvmId;
        mapping(address localToken => mapping(uint256 foreignEvmChainId => address foreignToken)) _localToForeignToken;
        mapping(address foreignToken => mapping(uint256 foreignEvmChainId => address localToken)) _foreignToLocalToken;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.CctpV2BridgeConfig")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CctpV2BridgeConfigStorageLocation =
        0xfddff817c79375fc2894a034cbd193828d9a03a3c9ab698ec061f44863e21100;

    function _getCctpV2BridgeConfigStorage() private pure returns (CctpV2BridgeConfigStorage storage $) {
        assembly {
            $.slot := CctpV2BridgeConfigStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority) external initializer {
        emit CctpDomainRegistered(MAINNET_CHAIN_ID, MAINNET_CCTP_DOMAIN);

        __AccessManaged_init(initialAuthority);
    }

    /// @inheritdoc IBridgeConfig
    function isRouteSupported(address inputToken, uint256 foreignChainId, address outputToken)
        external
        view
        override
        returns (bool)
    {
        CctpV2BridgeConfigStorage storage $ = _getCctpV2BridgeConfigStorage();
        return (foreignChainId == MAINNET_CHAIN_ID || $._evmToCctpId[foreignChainId] != 0)
            && $._localToForeignToken[inputToken][foreignChainId] == outputToken;
    }

    /// @inheritdoc ICctpV2BridgeConfig
    function getCctpDomain(uint256 evmChainId) external view override returns (uint32) {
        if (evmChainId == MAINNET_CHAIN_ID) {
            return MAINNET_CCTP_DOMAIN;
        }
        uint32 cctpDomain = _getCctpV2BridgeConfigStorage()._evmToCctpId[evmChainId];
        if (cctpDomain == 0) {
            revert Errors.CctpDomainNotRegistered();
        }
        return cctpDomain;
    }

    /// @inheritdoc ICctpV2BridgeConfig
    function getForeignToken(address localToken, uint256 foreignEvmChainId) external view override returns (address) {
        address foreignToken = _getCctpV2BridgeConfigStorage()._localToForeignToken[localToken][foreignEvmChainId];
        if (foreignToken == address(0)) {
            revert Errors.CctpForeignTokenNotRegistered();
        }
        return foreignToken;
    }

    /// @inheritdoc ICctpV2BridgeConfig
    function setCctpDomain(uint256 evmChainId, uint32 cctpDomain) external override restricted {
        CctpV2BridgeConfigStorage storage $ = _getCctpV2BridgeConfigStorage();

        if (evmChainId == 0) {
            revert Errors.ZeroChainId();
        }
        if (evmChainId == MAINNET_CHAIN_ID) {
            revert Errors.ProtectedChainId();
        }
        if (cctpDomain == MAINNET_CCTP_DOMAIN) {
            revert Errors.ProtectedCctpDomain();
        }

        uint32 oldDomain = $._evmToCctpId[evmChainId];
        if (oldDomain != 0) {
            delete $._cctpToEvmId[oldDomain];
        }

        uint256 oldEvmChainId = $._cctpToEvmId[cctpDomain];
        if (oldEvmChainId != 0) {
            delete $._evmToCctpId[oldEvmChainId];
        }

        $._evmToCctpId[evmChainId] = cctpDomain;
        $._cctpToEvmId[cctpDomain] = evmChainId;
        emit CctpDomainRegistered(evmChainId, cctpDomain);
    }

    /// @inheritdoc ICctpV2BridgeConfig
    function setForeignToken(address localToken, uint256 foreignEvmChainId, address foreignToken)
        external
        override
        restricted
    {
        CctpV2BridgeConfigStorage storage $ = _getCctpV2BridgeConfigStorage();

        if (localToken == address(0) || foreignToken == address(0)) {
            revert Errors.ZeroTokenAddress();
        }
        if (foreignEvmChainId == 0) {
            revert Errors.ZeroChainId();
        }

        address oldForeignToken = $._localToForeignToken[localToken][foreignEvmChainId];
        if (oldForeignToken != address(0)) {
            delete $._foreignToLocalToken[oldForeignToken][foreignEvmChainId];
        }

        address oldLocalToken = $._foreignToLocalToken[foreignToken][foreignEvmChainId];
        if (oldLocalToken != address(0)) {
            delete $._localToForeignToken[oldLocalToken][foreignEvmChainId];
        }

        $._localToForeignToken[localToken][foreignEvmChainId] = foreignToken;
        $._foreignToLocalToken[foreignToken][foreignEvmChainId] = localToken;
        emit ForeignTokenRegistered(localToken, foreignEvmChainId, foreignToken);
    }
}
