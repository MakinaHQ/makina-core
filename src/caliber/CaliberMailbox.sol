// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "../interfaces/IBridgeController.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox, IMachineEndpoint} from "../interfaces/ICaliberMailbox.sol";
import {IMachineEndpoint} from "../interfaces/IMachineEndpoint.sol";
import {IMakinaGovernable} from "../interfaces/IMakinaGovernable.sol";
import {ISpokeCoreRegistry} from "../interfaces/ISpokeCoreRegistry.sol";
import {ITokenRegistry} from "../interfaces/ITokenRegistry.sol";
import {BridgeController} from "../bridge/controller/BridgeController.sol";
import {Errors} from "../libraries/Errors.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";
import {MakinaGovernable} from "../utils/MakinaGovernable.sol";

contract CaliberMailbox is MakinaGovernable, ReentrancyGuardUpgradeable, BridgeController, ICaliberMailbox {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using SafeERC20 for IERC20;

    uint256 public immutable hubChainId;

    /// @custom:storage-location erc7201:makina.storage.CaliberMailbox
    struct CaliberMailboxStorage {
        address _hubMachine;
        address _caliber;
        mapping(uint16 bridgeId => address adapter) _hubBridgeAdapters;
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

    function initialize(IMakinaGovernable.MakinaGovernableInitParams calldata mgParams, address _hubMachine)
        external
        override
        initializer
    {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        $._hubMachine = _hubMachine;
        __ReentrancyGuard_init();
        __MakinaGovernable_init(mgParams);
    }

    modifier onlyFactory() {
        if (msg.sender != ISpokeCoreRegistry(registry).coreFactory()) {
            revert Errors.NotFactory();
        }
        _;
    }

    /// @inheritdoc ICaliberMailbox
    function caliber() external view override returns (address) {
        return _getCaliberStorage()._caliber;
    }

    /// @inheritdoc ICaliberMailbox
    function getHubBridgeAdapter(uint16 bridgeId) external view override returns (address) {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        if ($._hubBridgeAdapters[bridgeId] == address(0)) {
            revert Errors.HubBridgeAdapterNotSet();
        }
        return $._hubBridgeAdapters[bridgeId];
    }

    /// @inheritdoc ICaliberMailbox
    function getSpokeCaliberAccountingData() external view override returns (SpokeCaliberAccountingData memory data) {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        (data.netAum, data.positions, data.baseTokens) = ICaliber($._caliber).getDetailedAum();

        uint256 len = $._bridgesIn.length();
        data.bridgesIn = new bytes[](len);
        for (uint256 i; i < len; ++i) {
            (address token, uint256 amount) = $._bridgesIn.at(i);
            data.bridgesIn[i] = abi.encode(token, amount);
        }

        len = $._bridgesOut.length();
        data.bridgesOut = new bytes[](len);
        for (uint256 i; i < len; ++i) {
            (address token, uint256 amount) = $._bridgesOut.at(i);
            data.bridgesOut[i] = abi.encode(token, amount);
        }
    }

    /// @inheritdoc IMachineEndpoint
    function manageTransfer(address token, uint256 amount, bytes calldata data) external override nonReentrant {
        CaliberMailboxStorage storage $ = _getCaliberStorage();

        if (msg.sender == $._caliber) {
            address outputToken =
                ITokenRegistry(ISpokeCoreRegistry(registry).tokenRegistry()).getForeignToken(token, hubChainId);

            (uint16 bridgeId, uint256 minOutputAmount) = abi.decode(data, (uint16, uint256));

            address recipient = $._hubBridgeAdapters[bridgeId];
            if (recipient == address(0)) {
                revert Errors.HubBridgeAdapterNotSet();
            }

            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

            (bool exists, uint256 bridgeOut) = $._bridgesOut.tryGet(token);
            $._bridgesOut.set(token, exists ? bridgeOut + amount : amount);

            _scheduleOutBridgeTransfer(bridgeId, hubChainId, recipient, token, amount, outputToken, minOutputAmount);
        } else if (_isBridgeAdapter(msg.sender)) {
            (, uint256 inputAmount, bool refund) = abi.decode(data, (uint256, uint256, bool));

            if (refund) {
                uint256 bridgeOut = $._bridgesOut.get(token);
                $._bridgesOut.set(token, bridgeOut - inputAmount);
            } else {
                (bool exists, uint256 bridgeIn) = $._bridgesIn.tryGet(token);
                $._bridgesIn.set(token, exists ? bridgeIn + inputAmount : inputAmount);
            }

            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            IERC20(token).forceApprove($._caliber, amount);
            ICaliber($._caliber).notifyIncomingTransfer(token, amount);
        } else {
            revert Errors.UnauthorizedCaller();
        }
    }

    /// @inheritdoc IBridgeController
    function sendOutBridgeTransfer(uint16 bridgeId, uint256 transferId, bytes calldata data) external onlyOperator {
        _sendOutBridgeTransfer(bridgeId, transferId, data);
    }

    /// @inheritdoc IBridgeController
    function authorizeInBridgeTransfer(uint16 bridgeId, bytes32 messageHash) external notRecoveryMode onlyMechanic {
        _authorizeInBridgeTransfer(bridgeId, messageHash);
    }

    /// @inheritdoc IBridgeController
    function claimInBridgeTransfer(uint16 bridgeId, uint256 transferId) external onlyOperator {
        _claimInBridgeTransfer(bridgeId, transferId);
    }

    /// @inheritdoc IBridgeController
    function cancelOutBridgeTransfer(uint16 bridgeId, uint256 transferId) external onlyOperator {
        _cancelOutBridgeTransfer(bridgeId, transferId);
    }

    /// @inheritdoc ICaliberMailbox
    function setCaliber(address _caliber) external override onlyFactory {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        if ($._caliber != address(0)) {
            revert Errors.CaliberAlreadySet();
        }
        $._caliber = _caliber;

        emit CaliberSet(_caliber);
    }

    /// @inheritdoc ICaliberMailbox
    function setHubBridgeAdapter(uint16 bridgeId, address adapter) external restricted {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        if ($._hubBridgeAdapters[bridgeId] != address(0)) {
            revert Errors.HubBridgeAdapterAlreadySet();
        }
        if (adapter == address(0)) {
            revert Errors.ZeroBridgeAdapterAddress();
        }
        $._hubBridgeAdapters[bridgeId] = adapter;

        emit HubBridgeAdapterSet(uint256(bridgeId), adapter);
    }

    /// @inheritdoc IBridgeController
    function setOutTransferEnabled(uint16 bridgeId, bool enabled) external override onlyRiskManagerTimelock {
        _setOutTransferEnabled(bridgeId, enabled);
    }

    /// @inheritdoc IBridgeController
    function setMaxBridgeLossBps(uint16 bridgeId, uint256 maxBridgeLossBps) external override onlyRiskManagerTimelock {
        _setMaxBridgeLossBps(bridgeId, maxBridgeLossBps);
    }

    /// @inheritdoc IBridgeController
    function resetBridgingState(address token) external override onlySecurityCouncil {
        CaliberMailboxStorage storage $ = _getCaliberStorage();

        $._bridgesIn.remove(token);
        $._bridgesOut.remove(token);

        BridgeControllerStorage storage $bc = _getBridgeControllerStorage();
        uint256 len = $bc._supportedBridges.length;
        for (uint256 i; i < len; ++i) {
            address bridgeAdapter = $bc._bridgeAdapters[$bc._supportedBridges[i]];
            IBridgeAdapter(bridgeAdapter).withdrawPendingFunds(token);
        }

        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).forceApprove($._caliber, amount);
        ICaliber($._caliber).notifyIncomingTransfer(token, amount);

        emit BridgingStateReset(token);
    }
}
