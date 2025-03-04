// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBaseMakinaRegistry} from "./IBaseMakinaRegistry.sol";

interface ISpokeRegistry is IBaseMakinaRegistry {
    event CaliberFactoryChange(address indexed oldCaliberFactory, address indexed newCaliberFactory);
    event SpokeCaliberMailboxBeaconChange(
        address indexed oldSpokeCaliberMailboxBeacon, address indexed newSpokeCaliberMailboxBeacon
    );

    /// @notice Address of the caliber factory.
    function caliberFactory() external view returns (address);

    /// @notice Address of the hub dual mailbox beacon contract.
    function spokeCaliberMailboxBeacon() external view returns (address);

    /// @notice Sets the caliber factory address.
    /// @param _caliberFactory The caliber factory address.
    function setCaliberFactory(address _caliberFactory) external;

    /// @notice Sets the spoke caliber mailbox beacon address.
    /// @param _spokeCaliberMailboxBeacon The spoke caliber mailbox beacon address.
    function setSpokeCaliberMailboxBeacon(address _spokeCaliberMailboxBeacon) external;
}
