// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IBridgeAdapter} from "../../interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "../../interfaces/IBridgeController.sol";
import {IMachineEndpoint} from "../../interfaces/IMachineEndpoint.sol";
import {Errors} from "../../libraries/Errors.sol";

abstract contract BridgeAdapter is ReentrancyGuardUpgradeable, IBridgeAdapter {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    /// @dev Full scale value in basis points
    uint256 private constant MAX_BPS = 10_000;

    /// @inheritdoc IBridgeAdapter
    address public immutable override approvalTarget;

    /// @inheritdoc IBridgeAdapter
    address public immutable override executionTarget;

    /// @inheritdoc IBridgeAdapter
    address public immutable override receiveSource;

    /// @dev EnumerableSet wrapper supporting efficient clearing by switching to a new version.
    struct VersionedUintSet {
        mapping(uint256 => EnumerableSet.UintSet) _sets;
        uint256 _currentVersion;
    }

    /// @custom:storage-location erc7201:makina.storage.BridgeAdapter
    struct BridgeAdapterStorage {
        address _controller;
        uint16 _bridgeId;
        uint256 _nextOutTransferId;
        uint256 _nextInTransferId;
        mapping(uint256 outTransferId => OutBridgeTransfer transfer) _outgoingTransfers;
        mapping(uint256 inTransferId => InBridgeTransfer transfer) _incomingTransfers;
        mapping(address token => VersionedUintSet) _pendingOutTransferIds;
        mapping(address token => VersionedUintSet) _sentOutTransferIds;
        mapping(address token => VersionedUintSet) _pendingInTransferIds;
        mapping(bytes32 messageHash => bool isExpected) _expectedInMessages;
        mapping(address token => uint256 amount) _reservedBalances;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.BridgeAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BridgeAdapterStorageLocation =
        0xe24ea70efbf545f0256b406d064fa196624401f48d56c665b3e8bc995282c700;

    function _getBridgeAdapterStorage() internal pure returns (BridgeAdapterStorage storage $) {
        assembly {
            $.slot := BridgeAdapterStorageLocation
        }
    }

    constructor(address _approvalTarget, address _executionTarget, address _receiveSource) {
        approvalTarget = _approvalTarget;
        executionTarget = _executionTarget;
        receiveSource = _receiveSource;
    }

    function __BridgeAdapter_init(address _controller, uint16 _bridgeId) internal onlyInitializing {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();
        $._controller = _controller;
        $._bridgeId = _bridgeId;
        $._nextOutTransferId = 1;
        $._nextInTransferId = 1;
        __ReentrancyGuard_init();
    }

    modifier onlyController() {
        if (msg.sender != _getBridgeAdapterStorage()._controller) {
            revert Errors.NotController();
        }
        _;
    }

    /// @inheritdoc IBridgeAdapter
    function controller() external view override returns (address) {
        return _getBridgeAdapterStorage()._controller;
    }

    /// @inheritdoc IBridgeAdapter
    function bridgeId() external view override returns (uint16) {
        return _getBridgeAdapterStorage()._bridgeId;
    }

    /// @inheritdoc IBridgeAdapter
    function nextOutTransferId() external view override returns (uint256) {
        return _getBridgeAdapterStorage()._nextOutTransferId;
    }

    /// @inheritdoc IBridgeAdapter
    function nextInTransferId() external view override returns (uint256) {
        return _getBridgeAdapterStorage()._nextInTransferId;
    }

    /// @inheritdoc IBridgeAdapter
    function scheduleOutBridgeTransfer(
        uint256 destinationChainId,
        address recipient,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 minOutputAmount
    ) external override nonReentrant onlyController {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();

        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), inputAmount);

        uint256 id = $._nextOutTransferId++;
        bytes memory encodedMessage = abi.encode(
            BridgeMessage(
                id,
                address(this),
                recipient,
                block.chainid,
                destinationChainId,
                inputToken,
                inputAmount,
                outputToken,
                minOutputAmount
            )
        );
        $._outgoingTransfers[id] = OutBridgeTransfer(
            recipient, destinationChainId, inputToken, inputAmount, outputToken, minOutputAmount, encodedMessage
        );
        _getSet($._pendingOutTransferIds[inputToken]).add(id);
        $._reservedBalances[inputToken] += inputAmount;

        bytes32 messageHash = keccak256(encodedMessage);

        emit OutBridgeTransferScheduled(id, messageHash);
    }

    /// @inheritdoc IBridgeAdapter
    function authorizeInBridgeTransfer(bytes32 messageHash) external override onlyController {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();

        if ($._expectedInMessages[messageHash]) {
            revert Errors.MessageAlreadyAuthorized();
        }
        $._expectedInMessages[messageHash] = true;

        emit InBridgeTransferAuthorized(messageHash);
    }

    /// @inheritdoc IBridgeAdapter
    function claimInBridgeTransfer(uint256 id) external override nonReentrant onlyController {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();

        InBridgeTransfer storage receipt = $._incomingTransfers[id];
        if (!_getSet($._pendingInTransferIds[receipt.outputToken]).remove(id)) {
            revert Errors.InvalidTransferStatus();
        }

        IERC20(receipt.outputToken).forceApprove($._controller, receipt.outputAmount);
        IMachineEndpoint($._controller).manageTransfer(
            receipt.outputToken, receipt.outputAmount, abi.encode(receipt.originChainId, receipt.inputAmount, false)
        );

        $._reservedBalances[receipt.outputToken] -= receipt.outputAmount;

        emit InBridgeTransferClaimed(id);
    }

    /// @inheritdoc IBridgeAdapter
    function withdrawPendingFunds(address token) external nonReentrant onlyController {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();

        _clearSet($._pendingOutTransferIds[token]);
        _clearSet($._sentOutTransferIds[token]);
        _clearSet($._pendingInTransferIds[token]);
        $._reservedBalances[token] = 0;

        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount != 0) {
            IERC20(token).safeTransfer($._controller, amount);
        }

        emit PendingFundsWithdrawn(token, amount);
    }

    /// @dev Updates contract state before sending out a bridge transfer.
    function _beforeSendOutBridgeTransfer(uint256 id) internal {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();
        OutBridgeTransfer storage receipt = $._outgoingTransfers[id];
        if (!_getSet($._pendingOutTransferIds[receipt.inputToken]).remove(id)) {
            revert Errors.InvalidTransferStatus();
        }
        _getSet($._sentOutTransferIds[receipt.inputToken]).add(id);
        $._reservedBalances[receipt.inputToken] -= receipt.inputAmount;

        emit OutBridgeTransferSent(id);
    }

    /// @dev Cancels an outgoing bridge transfer that is either scheduled or refunded.
    function _cancelOutBridgeTransfer(uint256 id) internal {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();
        OutBridgeTransfer storage receipt = $._outgoingTransfers[id];

        if (_getSet($._sentOutTransferIds[receipt.inputToken]).remove(id)) {
            if (
                IERC20(receipt.inputToken).balanceOf(address(this))
                    < $._reservedBalances[receipt.inputToken] + receipt.inputAmount
            ) {
                revert Errors.InsufficientBalance();
            }
        } else if (_getSet($._pendingOutTransferIds[receipt.inputToken]).remove(id)) {
            $._reservedBalances[receipt.inputToken] -= receipt.inputAmount;
        } else {
            revert Errors.InvalidTransferStatus();
        }

        IERC20(receipt.inputToken).forceApprove($._controller, receipt.inputAmount);
        IMachineEndpoint($._controller).manageTransfer(
            receipt.inputToken, receipt.inputAmount, abi.encode(receipt.destinationChainId, receipt.inputAmount, true)
        );

        emit OutBridgeTransferCancelled(id);
    }

    /// @dev Updates contract state when receiving an incoming bridge transfer.
    function _receiveInBridgeTransfer(bytes memory encodedMessage, address receivedToken, uint256 receivedAmount)
        internal
    {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();

        bytes32 messageHash = keccak256(encodedMessage);
        if (!$._expectedInMessages[messageHash]) {
            revert Errors.UnexpectedMessage();
        }
        delete $._expectedInMessages[messageHash];

        BridgeMessage memory message = abi.decode(encodedMessage, (BridgeMessage));

        if (message.destinationChainId != block.chainid) {
            revert Errors.InvalidRecipientChainId();
        }
        if (receivedToken != message.outputToken) {
            revert Errors.InvalidOutputToken();
        }

        uint256 _maxBridgeLossBps = IBridgeController($._controller).getMaxBridgeLossBps($._bridgeId);
        if (
            receivedAmount < message.minOutputAmount
                || receivedAmount < message.inputAmount.mulDiv(MAX_BPS - _maxBridgeLossBps, MAX_BPS, Math.Rounding.Ceil)
        ) {
            revert Errors.MaxValueLossExceeded();
        }
        if (message.inputAmount < receivedAmount) {
            revert Errors.InvalidInputAmount();
        }

        uint256 id = $._nextInTransferId++;
        $._incomingTransfers[id] = InBridgeTransfer(
            message.sender,
            message.originChainId,
            message.inputToken,
            message.inputAmount,
            receivedToken,
            receivedAmount
        );
        _getSet($._pendingInTransferIds[receivedToken]).add(id);
        $._reservedBalances[receivedToken] += receivedAmount;
        emit InBridgeTransferReceived(id);
    }

    /// @dev Returns a reference to the current active set for this versioned set.
    function _getSet(VersionedUintSet storage self) internal view returns (EnumerableSet.UintSet storage) {
        return self._sets[self._currentVersion];
    }

    /// @dev Virtually clears the set by incrementing the version.
    ///      All future operations will apply to a fresh, empty set.
    ///      Previous versions remain in storage and are not deleted.
    function _clearSet(VersionedUintSet storage self) internal {
        ++self._currentVersion;
    }
}
