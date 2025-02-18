// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMailbox} from "./IMailbox.sol";

interface ICaliberMailbox is IMailbox {
    error NotCaliber();

    struct AccountingData {
        uint256 accountingTime;
        uint256 totalAccountingTokenValue;
        bytes[] totalReceivedFromHM; // abi.encode(baseToken, nativeValue)
        bytes[] totalSentToHM; // abi.encode(baseToken, nativeValue)
        bytes[] positions; // abi.encode(positionId, positionSize)
    }

    /// @notice Address of the associated caliber.
    function caliber() external view returns (address);

    /// @notice Notifies the mailbox with the last aum reported by the caliber.
    /// @param aum The last reported aum.
    function notifyAccountingSlim(uint256 aum) external;

    /// @notice Returns the accounting data of associated caliber.
    /// @return data The accounting data.
    function getAccountingData() external view returns (AccountingData memory data);
}
