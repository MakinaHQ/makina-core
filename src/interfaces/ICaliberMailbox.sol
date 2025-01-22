// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMailbox} from "./IMailbox.sol";

interface ICaliberMailbox is IMailbox {
    error NotCaliber();

    /// @notice Address of the associated caliber.
    function caliber() external view returns (address);

    /// @notice Notifies the mailbox with the last aum reported by the caliber.
    /// @param aum The last reported aum.
    function notifyAccountingSlim(uint256 aum) external;
}
