// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAcrossV3SpokePool} from "../../src/interfaces/IAcrossV3SpokePool.sol";

/// @dev IMockAcrossV3SpokePool contract for testing use only
interface IMockAcrossV3SpokePool is IAcrossV3SpokePool {
    error ExpiredFillDeadline();
    error InvalidDepositId();

    event FundsDeposited(
        bytes32 inputToken,
        bytes32 outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 indexed destinationChainId,
        uint256 indexed depositId,
        uint32 quoteTimestamp,
        uint32 fillDeadline,
        uint32 exclusivityDeadline,
        bytes32 indexed depositor,
        bytes32 recipient,
        bytes32 exclusiveRelayer,
        bytes message
    );

    struct DepositV3Params {
        bytes32 depositor;
        bytes32 recipient;
        bytes32 inputToken;
        bytes32 outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 destinationChainId;
        bytes32 exclusiveRelayer;
        uint256 depositId;
        uint32 quoteTimestamp;
        uint32 fillDeadline;
        uint32 exclusivityParameter;
        bytes message;
    }

    function numberOfDeposits() external view returns (uint256);

    function outputAmountOffsetBps() external view returns (uint256);

    function outputAmountOffsetDirection() external view returns (bool);

    function alteratedMessageMode() external view returns (bool);

    function cancelFeeBps() external view returns (uint256);

    function getTransferData(uint256 depositId) external view returns (DepositV3Params memory);

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
    ) external payable;

    function settleTransfer(uint256 depositId) external;

    function cancelTransfer(uint256 depositId) external;

    function setOutputOffset(uint256 offsetBps, bool offsetDirection) external;

    function setAlteratedMessageMode(bool isActive) external;

    function setCancelFeeBps(uint256 feeBps) external;
}
