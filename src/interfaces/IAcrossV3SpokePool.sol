// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAcrossV3SpokePool {
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
}
