// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {
    IOFT,
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {IBridgeAdapter} from "../../interfaces/IBridgeAdapter.sol";
import {ICoreRegistry} from "../../interfaces/ICoreRegistry.sol";
import {ILayerZeroV2Config} from "../../interfaces/ILayerZeroV2Config.sol";
import {BridgeAdapter} from "./BridgeAdapter.sol";
import {Errors} from "../../libraries/Errors.sol";
import {LzOptionsBuilder} from "../../libraries/LzOptionsBuilder.sol";

contract LayerZeroV2BridgeAdapter is BridgeAdapter, ILayerZeroComposer {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    event LzGuidCreated(bytes32 indexed guid, uint256 indexed transferId);

    uint16 private constant LAYER_ZERO_V2_BRIDGE_ID = 2;

    constructor(address _registry, address _layerZeroV2Endpoint)
        BridgeAdapter(_registry, address(0), address(0), _layerZeroV2Endpoint)
    {
        _disableInitializers();
    }

    /// @inheritdoc IBridgeAdapter
    function initialize(address _controller, bytes calldata) external override initializer {
        __BridgeAdapter_init(_controller, LAYER_ZERO_V2_BRIDGE_ID);
    }

    /// @dev Allows the contract to receive Ether.
    receive() external payable {}

    /// @inheritdoc ILayerZeroComposer
    function lzCompose(
        address _from,
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) external payable {
        if (msg.sender != receiveSource) {
            revert Errors.UnauthorizedSource();
        }
        bytes memory encodedMessage = OFTComposeMsgCodec.composeMsg(_message);
        address tokenSent = IOFT(_from).token();
        uint256 amount = OFTComposeMsgCodec.amountLD(_message);

        address config = ICoreRegistry(registry).bridgeConfig(LAYER_ZERO_V2_BRIDGE_ID);
        if (ILayerZeroV2Config(config).tokenToOft(tokenSent) != _from) {
            revert Errors.InvalidOft();
        }

        // ensure there is enough non-reserved balance to cover the incoming transfer
        if (
            IERC20(tokenSent).balanceOf(address(this))
                < _getBridgeAdapterStorage()._reservedBalances[tokenSent] + amount
        ) {
            revert Errors.InsufficientBalance();
        }

        _receiveInBridgeTransfer(encodedMessage, tokenSent, amount);
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

        address config = ICoreRegistry(registry).bridgeConfig(LAYER_ZERO_V2_BRIDGE_ID);
        uint32 lzChainId = ILayerZeroV2Config(config).evmToLzChainId(receipt.destinationChainId);
        address oft = ILayerZeroV2Config(config).tokenToOft(receipt.inputToken);

        if (IOFT(oft).approvalRequired()) {
            IERC20(receipt.inputToken).forceApprove(oft, receipt.inputAmount);
        }

        (uint128 lzReceiveGas, uint128 lzComposeGas, uint256 maxValue) = abi.decode(data, (uint128, uint128, uint256));

        bytes memory options;
        if (lzReceiveGas != 0 || lzComposeGas != 0) {
            options = LzOptionsBuilder.newOptions();
            if (lzReceiveGas != 0) {
                options = LzOptionsBuilder.addExecutorLzReceiveOption(options, lzReceiveGas);
            }
            if (lzComposeGas != 0) {
                options = LzOptionsBuilder.addExecutorLzComposeOption(options, 0, lzComposeGas);
            }
        } else {
            options = "";
        }

        SendParam memory sendParam = SendParam({
            dstEid: lzChainId,
            to: bytes32(uint256(uint160(receipt.recipient))),
            amountLD: receipt.inputAmount,
            minAmountLD: receipt.inputAmount,
            extraOptions: options,
            composeMsg: receipt.encodedMessage,
            oftCmd: ""
        });

        MessagingFee memory mf = IOFT(oft).quoteSend(sendParam, false);
        if (mf.nativeFee > maxValue) {
            revert Errors.ExceededMaxFee(mf.nativeFee, maxValue);
        }

        (MessagingReceipt memory mr, OFTReceipt memory oftr) =
            IOFT(oft).send{value: mf.nativeFee}(sendParam, mf, address(this)); // solhint-disable-line check-send-result

        if (oftr.amountSentLD != receipt.inputAmount) {
            revert Errors.InvalidLzSentAmount();
        }
        if (oftr.amountReceivedLD < receipt.minOutputAmount) {
            revert Errors.MaxValueLossExceeded();
        }

        emit LzGuidCreated(mr.guid, transferId);
    }
}
