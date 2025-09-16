// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ICoreRegistry} from "./ICoreRegistry.sol";

interface ISpokeCoreRegistry is ICoreRegistry {
    event CaliberMailboxBeaconChanged(address indexed oldCaliberMailboxBeacon, address indexed newCaliberMailboxBeacon);

    /// @notice Address of the caliber mailbox beacon.
    function caliberMailboxBeacon() external view returns (address);

    /// @notice Sets the caliber mailbox beacon address.
    /// @param _caliberMailboxBeacon The caliber mailbox beacon address.
    function setCaliberMailboxBeacon(address _caliberMailboxBeacon) external;
}
