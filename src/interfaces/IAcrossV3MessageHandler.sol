// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAcrossV3MessageHandler {
    function handleV3AcrossMessage(address tokenSent, uint256 amount, address relayer, bytes memory message) external;
}
