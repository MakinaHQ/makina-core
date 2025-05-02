// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from  "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAcrossV3MessageHandler} from "src/interfaces/IAcrossV3MessageHandler.sol";
import {IMockAcrossV3SpokePool} from "test/mocks/IMockAcrossV3SpokePool.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

/// @dev MockAcrossV3SpokePool contract for testing use only
/// Simulates AcrossV3 SpokePool depositV3Now behaviour on a single chain
contract MockAcrossV3SpokePool is IMockAcrossV3SpokePool {
    using SafeERC20 for IERC20;

    uint256 public override numberOfDeposits;

    uint256 public override outputAmountOffsetBps;
    bool public override outputAmountOffsetDirection;
    bool public override alteratedMessageMode;

    uint256 public override cancelFeeBps;

    mapping(uint256 depositId => DepositV3Params params) private _transfersParams;

    constructor() {
        numberOfDeposits = 1;
    }

    function getTransferData(uint256 depositId) external view override returns (DepositV3Params memory) {
        return _transfersParams[depositId];
    }

    function depositV3Now(
        address depositor,
        address recipient,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destinationChainId,
        address exclusiveRelayer,
        uint32 fillDeadlineOffset,
        uint32 exclusivityParameter,
        bytes calldata message
    ) external payable override {
        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), inputAmount);

        _transfersParams[numberOfDeposits] = DepositV3Params({
            depositor: _addressToBytes32(depositor),
            recipient: _addressToBytes32(recipient),
            inputToken: _addressToBytes32(inputToken),
            outputToken: _addressToBytes32(outputToken),
            inputAmount: inputAmount,
            outputAmount: outputAmount,
            destinationChainId: destinationChainId,
            exclusiveRelayer: _addressToBytes32(exclusiveRelayer),
            depositId: numberOfDeposits,
            quoteTimestamp: uint32(block.timestamp),
            fillDeadline: uint32(block.timestamp + fillDeadlineOffset),
            exclusivityParameter: exclusivityParameter,
            message: message
        });

        _depositV3(_transfersParams[numberOfDeposits]);

        numberOfDeposits++;
    }

    function settleTransfer(uint256 depositId) external {
        DepositV3Params memory params = _transfersParams[depositId];

        if (depositId == 0 || params.depositId != depositId) {
            revert InvalidDepositId();
        }
        if (params.fillDeadline < block.timestamp) {
            revert ExpiredFillDeadline();
        }

        delete _transfersParams[depositId];

        uint256 actualOutputAmount = outputAmountOffsetBps > 0
            ? outputAmountOffsetDirection
                ? params.outputAmount * (10_000 + outputAmountOffsetBps) / 10_000
                : params.outputAmount * (10_000 - outputAmountOffsetBps) / 10_000
            : params.outputAmount;

        IERC20(_bytes32ToAddress(params.inputToken)).safeTransfer(
            _bytes32ToAddress(params.recipient), actualOutputAmount
        );
        if (params.message.length > 0) {
            if (alteratedMessageMode) {
                IBridgeAdapter.BridgeMessage memory _message =
                    abi.decode(params.message, (IBridgeAdapter.BridgeMessage));
                _message.minOutputAmount = actualOutputAmount;
                params.message = abi.encode(_message);
            }
            IAcrossV3MessageHandler(_bytes32ToAddress(params.recipient)).handleV3AcrossMessage(
                _bytes32ToAddress(params.inputToken), actualOutputAmount, address(0), params.message
            );
        }
    }

    function cancelTransfer(uint256 depositId) external override {
        DepositV3Params memory params = _transfersParams[depositId];

        if (depositId == 0 || params.depositId != depositId) {
            revert InvalidDepositId();
        }
        if (params.fillDeadline < block.timestamp) {
            revert ExpiredFillDeadline();
        }

        delete _transfersParams[depositId];

        uint256 refundAmount = params.inputAmount * (10_000 - cancelFeeBps) / 10_000;
        IERC20(_bytes32ToAddress(params.inputToken)).safeTransfer(_bytes32ToAddress(params.depositor), refundAmount);
    }

    function setOutputOffset(uint256 offsetBps, bool offsetDirection) external override {
        outputAmountOffsetBps = offsetBps;
        outputAmountOffsetDirection = offsetDirection;
    }

    function setAlteratedMessageMode(bool isActive) external override {
        alteratedMessageMode = isActive;
    }

    function setCancelFeeBps(uint256 feeBps) external override{
        cancelFeeBps = feeBps;
    }

    function _depositV3(DepositV3Params memory params) internal {
        emit FundsDeposited(
            params.inputToken,
            params.outputToken,
            params.inputAmount,
            params.outputAmount,
            params.destinationChainId,
            params.depositId,
            params.quoteTimestamp,
            params.fillDeadline,
            params.exclusivityParameter,
            params.depositor,
            params.recipient,
            params.exclusiveRelayer,
            params.message
        );
    }

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function _bytes32ToAddress(bytes32 b) internal pure returns (address) {
        return address(uint160(uint256(b)));
    }
}
