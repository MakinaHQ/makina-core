// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "./ICaliber.sol";
import {IBridgeAdapterFactory} from "./IBridgeAdapterFactory.sol";

interface ICaliberFactory is IBridgeAdapterFactory {
    error NotCaliberMailbox();

    event SpokeCaliberCreated(address indexed machine, address indexed caliber, address indexed mailbox);

    /// @notice Caliber => Is a caliber deployed by this factory
    function isCaliber(address caliber) external view returns (bool);

    /// @notice CaliberMailbox => Is a caliber mailbox deployed by this factory
    function isCaliberMailbox(address mailbox) external view returns (bool);

    /// @notice Deploys a new Caliber instance.
    /// @param params The deployment parameters.
    /// @param hubMachine The address of the hub machine.
    /// @return caliber The address of the deployed Caliber instance.
    function createCaliber(ICaliber.CaliberInitParams calldata params, address hubMachine)
        external
        returns (address caliber);
}
