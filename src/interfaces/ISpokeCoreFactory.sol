// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ICaliber} from "./ICaliber.sol";
import {IMakinaGovernable} from "./IMakinaGovernable.sol";
import {IBridgeAdapterFactory} from "./IBridgeAdapterFactory.sol";

interface ISpokeCoreFactory is IBridgeAdapterFactory {
    event CaliberMailboxCreated(address indexed mailbox);

    /// @notice Address => Whether this is a CaliberMailbox instance deployed by this factory.
    function isCaliberMailbox(address mailbox) external view returns (bool);

    /// @notice Deploys a new Caliber instance with an associated CaliberMailbox.
    /// @param cParams The caliber initialization parameters.
    /// @param mgParams The makina governable initialization parameters.
    /// @param baParams The list of bridge adapter initialization parameters and controller configuration.
    /// @param accountingToken The address of the accounting token.
    /// @param salt The salt used to deploy the Caliber deterministically.
    /// @param setupAMFunctionRoles Whether to set roles for restricted functions on the deployed instance.
    /// @return caliber The address of the deployed Caliber instance.
    function createCaliber(
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        BridgeAdapterInitParams[] calldata baParams,
        address accountingToken,
        bytes32 salt,
        bool setupAMFunctionRoles
    ) external returns (address caliber);
}
