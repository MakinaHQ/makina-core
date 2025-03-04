// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliberMailbox} from "./ICaliberMailbox.sol";

interface ISpokeCaliberMailbox is ICaliberMailbox {
    struct SpokeCaliberAccountingData {
        uint256 netAum;
        bytes[] positions; // abi.encode(positionId, positionSize)
        bytes[] totalReceivedFromHM; // abi.encode(baseToken, nativeValue)
        bytes[] totalSentToHM; // abi.encode(baseToken, nativeValue)
    }

    /// @notice Chain ID of the hub.
    function hubChainId() external view returns (uint256);

    /// @notice Address of the associated machine mailbox.
    function hubMachineMailbox() external view returns (address);

    /// @notice Returns the accounting data of the associated caliber.
    /// @return data The accounting data.
    function getSpokeCaliberAccountingData() external view returns (SpokeCaliberAccountingData memory);
}
