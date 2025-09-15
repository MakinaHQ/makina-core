// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IBridgeController} from "./IBridgeController.sol";
import {IMakinaGovernable} from "./IMakinaGovernable.sol";

interface IMachineEndpoint is IBridgeController, IMakinaGovernable {
    /// @notice Manages the transfer of tokens between a machine and a caliber. The transfer direction depends on the caller.
    /// @param token The address of the token.
    /// @param amount The amount of tokens to transfer.
    /// @param data ABI-encoded parameters required for bridge-related transfers. Ignored for transfers between a machine and its hub caliber.
    function manageTransfer(address token, uint256 amount, bytes calldata data) external;
}
