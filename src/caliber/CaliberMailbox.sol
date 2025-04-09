// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {BridgeController} from "../bridge/controller/BridgeController.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox, IMachineEndpoint} from "../interfaces/ICaliberMailbox.sol";
import {IMachineEndpoint} from "../interfaces/IMachineEndpoint.sol";
import {ISpokeRegistry} from "../interfaces/ISpokeRegistry.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

contract CaliberMailbox is AccessManagedUpgradeable, BridgeController, ICaliberMailbox {
    uint256 public immutable hubChainId;

    /// @custom:storage-location erc7201:makina.storage.CaliberMailbox
    struct CaliberMailboxStorage {
        address _hubMachine;
        address _caliber;
        mapping(IBridgeAdapter.Bridge bridgeId => address adapter) _hubBridgeAdapters;
        EnumerableMap.AddressToUintMap _bridgesIn;
        EnumerableMap.AddressToUintMap _bridgesOut;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.CaliberMailbox")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CaliberMailboxStorageLocation =
        0xc8f2c10c9147366283b13eb82b7eca93d88636f13eec15d81ed4c6aa5006aa00;

    function _getCaliberStorage() private pure returns (CaliberMailboxStorage storage $) {
        assembly {
            $.slot := CaliberMailboxStorageLocation
        }
    }

    constructor(address _registry, uint256 _hubChainId) MakinaContext(_registry) {
        hubChainId = _hubChainId;
        _disableInitializers();
    }

    function initialize(address _hubMachine, address _initialAuthority) external override initializer {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        $._hubMachine = _hubMachine;
        __AccessManaged_init(_initialAuthority);
    }

    modifier onlyFactory() {
        if (msg.sender != ISpokeRegistry(registry).caliberFactory()) {
            revert NotFactory();
        }
        _;
    }

    /// @inheritdoc ICaliberMailbox
    function caliber() external view override returns (address) {
        return _getCaliberStorage()._caliber;
    }

    /// @inheritdoc ICaliberMailbox
    function getHubBridgeAdapter(IBridgeAdapter.Bridge bridgeId) external view override returns (address) {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        if ($._hubBridgeAdapters[bridgeId] == address(0)) {
            revert HubBridgeAdapterNotSet();
        }
        return $._hubBridgeAdapters[bridgeId];
    }

    /// @inheritdoc ICaliberMailbox
    function getSpokeCaliberAccountingData() external view override returns (SpokeCaliberAccountingData memory data) {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        (data.netAum, data.positions, data.baseTokens) = ICaliber($._caliber).getDetailedAum();
        // @TODO include bridgesIn and bridgesOut
    }

    /// @inheritdoc IMachineEndpoint
    function manageTransfer(address token, uint256 amount, bytes calldata data) external override {}

    /// @inheritdoc ICaliberMailbox
    function setCaliber(address _caliber) external override onlyFactory {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        if ($._caliber != address(0)) {
            revert CaliberAlreadySet();
        }
        $._caliber = _caliber;

        emit CaliberSet(_caliber);
    }

    /// @inheritdoc ICaliberMailbox
    function setHubBridgeAdapter(IBridgeAdapter.Bridge bridgeId, address adapter) external restricted {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        if ($._hubBridgeAdapters[bridgeId] != address(0)) {
            revert HubBridgeAdapterAlreadySet();
        }
        if (adapter == address(0)) {
            revert ZeroBridgeAdapterAddress();
        }
        $._hubBridgeAdapters[bridgeId] = adapter;

        emit HubBridgeAdapterSet(uint256(bridgeId), adapter);
    }
}
