// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BridgeController} from "../bridge/controller/BridgeController.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox, IMachineEndpoint} from "../interfaces/ICaliberMailbox.sol";
import {IMachineEndpoint} from "../interfaces/IMachineEndpoint.sol";
import {ISpokeRegistry} from "../interfaces/ISpokeRegistry.sol";
import {ITokenRegistry} from "../interfaces/ITokenRegistry.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

contract CaliberMailbox is AccessManagedUpgradeable, BridgeController, ICaliberMailbox {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using SafeERC20 for IERC20Metadata;

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

        uint256 len = $._bridgesIn.length();
        data.bridgesIn = new bytes[](len);
        for (uint256 i; i < len; i++) {
            (address token, uint256 amount) = $._bridgesIn.at(i);
            data.bridgesIn[i] = abi.encode(token, amount);
        }

        len = $._bridgesOut.length();
        data.bridgesOut = new bytes[](len);
        for (uint256 i; i < len; i++) {
            (address token, uint256 amount) = $._bridgesOut.at(i);
            data.bridgesOut[i] = abi.encode(token, amount);
        }
    }

    /// @inheritdoc IMachineEndpoint
    function manageTransfer(address token, uint256 amount, bytes calldata data) external override {
        CaliberMailboxStorage storage $ = _getCaliberStorage();

        if (msg.sender == $._caliber) {
            (IBridgeAdapter.Bridge bridgeId, uint256 minOutputAmount) =
                abi.decode(data, (IBridgeAdapter.Bridge, uint256));

            address outputToken =
                ITokenRegistry(ISpokeRegistry(registry).tokenRegistry()).getForeignToken(token, hubChainId);

            address recipient = $._hubBridgeAdapters[bridgeId];
            if (recipient == address(0)) {
                revert HubBridgeAdapterNotSet();
            }

            (bool exists, uint256 bridgeOut) = $._bridgesOut.tryGet(token);
            $._bridgesOut.set(token, exists ? bridgeOut + amount : amount);

            IERC20Metadata(token).safeTransferFrom(msg.sender, address(this), amount);
            _scheduleOutBridgeTransfer(bridgeId, hubChainId, recipient, token, amount, outputToken, minOutputAmount);
        } else if (_isAdapter(msg.sender)) {
            if (!ICaliber($._caliber).isBaseToken(token)) {
                revert ICaliber.NotBaseToken();
            }
            uint256 inputAmount = abi.decode(data, (uint256));

            (bool exists, uint256 bridgeIn) = $._bridgesIn.tryGet(token);
            $._bridgesIn.set(token, exists ? bridgeIn + inputAmount : inputAmount);

            IERC20Metadata(token).safeTransferFrom(msg.sender, $._caliber, amount);
        } else {
            revert UnauthorizedCaller();
        }
    }

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
