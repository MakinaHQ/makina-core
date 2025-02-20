// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMailbox} from "./IMailbox.sol";

interface ICaliberMailbox is IMailbox {
    error NotCaliber();

    /// @notice Initializer of the contract.
    /// @param machineEndpoint The address of the associated machine endpoint.
    /// @param caliber The address of the associated caliber.
    function initialize(address machineEndpoint, address caliber) external;

    /// @notice Address of the associated caliber.
    function caliber() external view returns (address);
}
