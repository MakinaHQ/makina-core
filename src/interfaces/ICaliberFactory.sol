// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "./ICaliber.sol";

interface ICaliberFactory {
    error NotMachine();

    event SpokeCaliberCreated(address indexed machine, address indexed caliber, address indexed mailbox);

    /// @notice Address of the Makina registry.
    function registry() external view returns (address);

    /// @notice Caliber => Is a caliber deployed by this factory
    function isCaliber(address caliber) external view returns (bool);

    /// @notice Deploys a new Caliber instance.
    /// @param params The deployment parameters.
    /// @param hubMachine The address of the hub machine.
    /// @return caliber The address of the deployed Caliber instance.
    function createCaliber(ICaliber.CaliberInitParams calldata params, address hubMachine)
        external
        returns (address caliber);
}
