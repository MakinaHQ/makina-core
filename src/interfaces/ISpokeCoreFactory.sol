// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "./ICaliber.sol";
import {IMakinaGovernable} from "./IMakinaGovernable.sol";
import {IBridgeAdapterFactory} from "./IBridgeAdapterFactory.sol";

interface ISpokeCoreFactory is IBridgeAdapterFactory {
    error NotCaliberMailbox();

    event SpokeCaliberCreated(address indexed machine, address indexed caliber, address indexed mailbox);

    /// @notice Caliber => Is a caliber deployed by this factory
    function isCaliber(address caliber) external view returns (bool);

    /// @notice CaliberMailbox => Is a caliber mailbox deployed by this factory
    function isCaliberMailbox(address mailbox) external view returns (bool);

    /// @notice Deploys a new Caliber instance.
    /// @param cParams The caliber initialization parameters.
    /// @param mgParams The makina governable initialization parameters.
    /// @param accountingToken The address of the accounting token.
    /// @param hubMachine The address of the hub machine.
    /// @return caliber The address of the deployed Caliber instance.
    function createCaliber(
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address accountingToken,
        address hubMachine
    ) external returns (address caliber);
}
