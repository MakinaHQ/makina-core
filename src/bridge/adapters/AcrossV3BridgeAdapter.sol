// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAcrossV3MessageHandler} from "../../interfaces/IAcrossV3MessageHandler.sol";
import {IBridgeAdapter} from "../../interfaces/IBridgeAdapter.sol";
import {IAcrossV3SpokePool} from "../../interfaces/IAcrossV3SpokePool.sol";
import {BridgeAdapter} from "./BridgeAdapter.sol";
import {Errors} from "../../libraries/Errors.sol";

contract AcrossV3BridgeAdapter is BridgeAdapter, IAcrossV3MessageHandler {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    uint16 private constant ACROSS_V3_BRIDGE_ID = 1;

    constructor(address _acrossV3SpokePool) BridgeAdapter(_acrossV3SpokePool, _acrossV3SpokePool, _acrossV3SpokePool) {
        _disableInitializers();
    }

    /// @inheritdoc IBridgeAdapter
    function initialize(address _controller, bytes calldata) external override initializer {
        __BridgeAdapter_init(_controller, ACROSS_V3_BRIDGE_ID);
    }

    /// @inheritdoc IBridgeAdapter
    function sendOutBridgeTransfer(uint256 transferId, bytes calldata data)
        external
        override
        nonReentrant
        onlyController
    {
        _beforeSendOutBridgeTransfer(transferId);

        (uint32 fillDeadlineOffset) = abi.decode(data, (uint32));
        OutBridgeTransfer storage receipt = _getBridgeAdapterStorage()._outgoingTransfers[transferId];

        IERC20(receipt.inputToken).forceApprove(executionTarget, receipt.inputAmount);
        IAcrossV3SpokePool(executionTarget).depositV3Now(
            address(this),
            receipt.recipient,
            receipt.inputToken,
            receipt.outputToken,
            receipt.inputAmount,
            receipt.minOutputAmount,
            receipt.destinationChainId,
            address(0),
            fillDeadlineOffset,
            0,
            receipt.encodedMessage
        );
    }

    /// @inheritdoc IBridgeAdapter
    function cancelOutBridgeTransfer(uint256 transferId) external override nonReentrant onlyController {
        _cancelOutBridgeTransfer(transferId);
    }

    /// @inheritdoc IBridgeAdapter
    function outBridgeTransferCancelDefault(uint256 transferId) public view returns (uint256) {
        BridgeAdapterStorage storage $ = _getBridgeAdapterStorage();
        OutBridgeTransfer storage receipt = $._outgoingTransfers[transferId];

        if (_getSet($._sentOutTransferIds[receipt.inputToken]).contains(transferId)) {
            if (
                IERC20(receipt.inputToken).balanceOf(address(this))
                    < $._reservedBalances[receipt.inputToken] + receipt.inputAmount
            ) {
                return $._reservedBalances[receipt.inputToken] + receipt.inputAmount
                    - IERC20(receipt.inputToken).balanceOf(address(this));
            }
        } else if (!_getSet($._pendingOutTransferIds[receipt.inputToken]).contains(transferId)) {
            revert Errors.InvalidTransferStatus();
        }
        return 0;
    }

    /// @inheritdoc IAcrossV3MessageHandler
    function handleV3AcrossMessage(address tokenSent, uint256 amount, address, /*relayer*/ bytes memory encodedMessage)
        external
        override
    {
        if (msg.sender != receiveSource) {
            revert Errors.UnauthorizedSource();
        }
        _receiveInBridgeTransfer(encodedMessage, tokenSent, amount);
    }
}
