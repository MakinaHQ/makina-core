// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IAcrossV3BridgeConfig} from "../../interfaces/IAcrossV3BridgeConfig.sol";
import {IBridgeConfig} from "../../interfaces/IBridgeConfig.sol";

contract AcrossV3BridgeConfig is AccessManagedUpgradeable, IAcrossV3BridgeConfig {
    /// @custom:storage-location erc7201:makina.storage.AcrossV3BridgeConfig
    struct AcrossV3BridgeConfigStorage {
        mapping(uint256 evmChainId => bool isSupported) _isForeignChainSupported;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.AcrossV3BridgeConfig")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AcrossV3BridgeConfigStorageLocation =
        0x55c9f27624440face9d60f824f50119631f5ca1c165e4b047f325c445d2b2500;

    function _getAcrossV3BridgeConfigStorage() internal pure returns (AcrossV3BridgeConfigStorage storage $) {
        assembly {
            $.slot := AcrossV3BridgeConfigStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc IBridgeConfig
    function isRouteSupported(address, /*inputToken*/ uint256 foreignChainId, address /*outputToken*/ )
        external
        view
        override
        returns (bool)
    {
        return isForeignChainSupported(foreignChainId);
    }

    /// @inheritdoc IAcrossV3BridgeConfig
    function isForeignChainSupported(uint256 foreignChainId) public view override returns (bool) {
        return _getAcrossV3BridgeConfigStorage()._isForeignChainSupported[foreignChainId];
    }

    /// @inheritdoc IAcrossV3BridgeConfig
    function setForeignChainSupported(uint256 foreignChainId, bool supported) external override restricted {
        _getAcrossV3BridgeConfigStorage()._isForeignChainSupported[foreignChainId] = supported;
    }
}
