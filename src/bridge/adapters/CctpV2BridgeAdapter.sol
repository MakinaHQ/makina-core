// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBridgeAdapter} from "../../interfaces/IBridgeAdapter.sol";
import {ICctpV2BridgeConfig} from "../../interfaces/ICctpV2BridgeConfig.sol";
import {ICctpV2DestinationCaller} from "../../interfaces/ICctpV2DestinationCaller.sol";
import {ICctpV2MessageTransmitter} from "../../interfaces/ICctpV2MessageTransmitter.sol";
import {ICctpV2TokenMessenger} from "../../interfaces/ICctpV2TokenMessenger.sol";
import {ICctpV2TokenMinter} from "../../interfaces/ICctpV2TokenMinter.sol";
import {BridgeAdapter} from "./BridgeAdapter.sol";
import {CctpV2Message} from "../../libraries/CctpV2Message.sol";
import {Errors} from "../../libraries/Errors.sol";

contract CctpV2BridgeAdapter is BridgeAdapter, ICctpV2DestinationCaller {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    uint16 private constant CCTP_V2_BRIDGE_ID = 3;

    constructor(address _registry, address _tokenMessenger, address _messageTransmitter)
        BridgeAdapter(_registry, _tokenMessenger, _tokenMessenger, _messageTransmitter)
    {
        _disableInitializers();
    }

    /// @inheritdoc IBridgeAdapter
    function initialize(address _controller, bytes calldata) external override initializer {
        __BridgeAdapter_init(_controller, CCTP_V2_BRIDGE_ID);
    }

    /// @inheritdoc ICctpV2DestinationCaller
    function receiveCctpV2Message(bytes calldata message, bytes calldata attestation) external nonReentrant {
        CctpV2Message.checkMessageLength(message);
        bytes memory encodedMessage = CctpV2Message.getHookData(message);
        uint32 srcDomain = CctpV2Message.getSourceDomain(message);
        bytes32 inputToken = CctpV2Message.getBurnToken(message);

        address tokenMinter = ICctpV2TokenMessenger(executionTarget).localMinter();
        address token = ICctpV2TokenMinter(tokenMinter).getLocalToken(srcDomain, inputToken);

        uint256 balBefore = IERC20(token).balanceOf(address(this));
        if (!ICctpV2MessageTransmitter(receiveSource).receiveMessage(message, attestation)) {
            revert Errors.CctpMessageReceptionFailed();
        }
        uint256 amount = IERC20(token).balanceOf(address(this)) - balBefore;

        _receiveInBridgeTransfer(encodedMessage, token, amount);
    }

    /// @inheritdoc BridgeAdapter
    function _outBridgeTransferCancelDefault(uint256 transferId) internal view override returns (uint256) {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();
        OutBridgeTransfer storage receipt = $._outgoingTransfers[transferId];

        if (!_getSet($._pendingOutTransferIds[receipt.inputToken]).contains(transferId)) {
            revert Errors.InvalidTransferStatus();
        }
        return 0;
    }

    /// @inheritdoc BridgeAdapter
    function _checkOutBridgeTransferIsCancellable(uint256 transferId) internal override {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();
        OutBridgeTransfer storage receipt = $._outgoingTransfers[transferId];

        if (_getSet($._pendingOutTransferIds[receipt.inputToken]).remove(transferId)) {
            $._reservedBalances[receipt.inputToken] -= receipt.inputAmount;
        } else {
            revert Errors.InvalidTransferStatus();
        }
    }

    /// @inheritdoc BridgeAdapter
    function _sendOutBridgeTransfer(uint256 transferId, bytes calldata data) internal override {
        OutBridgeTransfer storage receipt = _getBridgeAdapterStorage()._outgoingTransfers[transferId];

        uint32 destCctpDomain = ICctpV2BridgeConfig(_getConfig()).getCctpDomain(receipt.destinationChainId);

        (uint32 minFinalityThreshold) = abi.decode(data, (uint32));

        IERC20(receipt.inputToken).forceApprove(approvalTarget, receipt.inputAmount);
        ICctpV2TokenMessenger(executionTarget)
            .depositForBurnWithHook(
                receipt.inputAmount,
                destCctpDomain,
                CctpV2Message.addressToBytes32(receipt.recipient),
                receipt.inputToken,
                CctpV2Message.addressToBytes32(receipt.recipient),
                receipt.inputAmount - receipt.minOutputAmount,
                minFinalityThreshold,
                receipt.encodedMessage
            );
    }
}
