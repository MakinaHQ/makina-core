// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ICaliber} from "./ICaliber.sol";
import {IMakinaGovernable} from "./IMakinaGovernable.sol";
import {IBridgeAdapterFactory} from "./IBridgeAdapterFactory.sol";

interface ISpokeCoreFactory is IBridgeAdapterFactory {
    event CaliberMailboxCreated(address indexed mailbox, address indexed caliber, address indexed hubMachine);

    /// @notice Address => Whether this is a CaliberMailbox instance deployed by this factory.
    function isCaliberMailbox(address mailbox) external view returns (bool);

    /// @notice Deploys a new Caliber instance.
    /// @param cParams The caliber initialization parameters.
    /// @param mgParams The makina governable initialization parameters.
    /// @param accountingToken The address of the accounting token.
    /// @param hubMachine The address of the hub machine.
    /// @param salt The salt used to deploy the Caliber deterministically.
    /// @return caliber The address of the deployed Caliber instance.
    function createCaliber(
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address accountingToken,
        address hubMachine,
        bytes32 salt
    ) external returns (address caliber);
}
