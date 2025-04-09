// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAcrossV3MessageHandler} from "../../interfaces/IAcrossV3MessageHandler.sol";
import {IBridgeAdapter} from "../../interfaces/IBridgeAdapter.sol";
import {IAcrossV3SpokePool} from "../../interfaces/IAcrossV3SpokePool.sol";
import {BridgeAdapter} from "./BridgeAdapter.sol";

contract AcrossV3BridgeAdapter is BridgeAdapter, IAcrossV3MessageHandler {
    using SafeERC20 for IERC20Metadata;
    using EnumerableSet for EnumerableSet.UintSet;

    constructor(address _acrossV3SpokePool) BridgeAdapter(_acrossV3SpokePool, _acrossV3SpokePool, _acrossV3SpokePool) {}

    /// @inheritdoc IBridgeAdapter
    function initialize(address _controller, bytes calldata) external override initializer {
        __BridgeAdapter_init(_controller);
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

        IERC20Metadata(receipt.inputToken).forceApprove(executionTarget, receipt.inputAmount);
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

        if (receipt.status == OutTransferStatus.NULL) {
            revert InvalidTransferStatus();
        }
        if (
            receipt.status == OutTransferStatus.SENT
                && IERC20Metadata(receipt.inputToken).balanceOf(address(this))
                    < $._reservedBalances[receipt.inputToken] + receipt.inputAmount
        ) {
            return $._reservedBalances[receipt.inputToken] + receipt.inputAmount
                - IERC20Metadata(receipt.inputToken).balanceOf(address(this));
        }
        return 0;
    }

    /// @inheritdoc IAcrossV3MessageHandler
    function handleV3AcrossMessage(address tokenSent, uint256 amount, address, /*relayer*/ bytes memory encodedMessage)
        external
        override
    {
        if (msg.sender != receiveSource) {
            revert UnauthorizedSource();
        }
        _receiveInBridgeTransfer(encodedMessage, tokenSent, amount);
    }
}
