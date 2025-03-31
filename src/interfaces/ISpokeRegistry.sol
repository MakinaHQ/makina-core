// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBaseMakinaRegistry} from "./IBaseMakinaRegistry.sol";

interface ISpokeRegistry is IBaseMakinaRegistry {
    event CaliberFactoryChange(address indexed oldCaliberFactory, address indexed newCaliberFactory);
    event CaliberMailboxBeaconChange(address indexed oldCaliberMailboxBeacon, address indexed newCaliberMailboxBeacon);

    /// @notice Address of the caliber factory.
    function caliberFactory() external view returns (address);

    /// @notice Address of the caliber mailbox beacon.
    function caliberMailboxBeacon() external view returns (address);

    /// @notice Sets the caliber factory address.
    /// @param _caliberFactory The caliber factory address.
    function setCaliberFactory(address _caliberFactory) external;

    /// @notice Sets the caliber mailbox beacon address.
    /// @param _caliberMailboxBeacon The caliber mailbox beacon address.
    function setCaliberMailboxBeacon(address _caliberMailboxBeacon) external;
}
