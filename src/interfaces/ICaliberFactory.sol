// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ICaliberFactory {
    event CaliberCreated(address indexed caliber, address indexed machineEndpoint);

    /// @notice Address => Whether this is a Caliber instance deployed by this factory.
    function isCaliber(address caliber) external view returns (bool);
}
