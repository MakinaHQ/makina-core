// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "./ICaliber.sol";

interface ICaliberFactory {
    error NotMachine();

    event CaliberDeployed(address indexed caliber);

    /// @notice Address of the Makina registry.
    function registry() external view returns (address);

    /// @notice Caliber => Is a caliber deployed by this factory
    function isCaliber(address caliber) external view returns (bool);

    /// @notice Deploys a new Caliber instance.
    /// @param params The deployment parameters.
    /// @return caliber The address of the deployed Caliber instance.
    function createCaliber(ICaliber.CaliberInitParams calldata params) external returns (address caliber);
}
