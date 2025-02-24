// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineMailbox} from "./IMachineMailbox.sol";
import {ICaliberMailbox} from "./ICaliberMailbox.sol";

interface IHubDualMailbox is IMachineMailbox, ICaliberMailbox {
    error NotBaseToken();

    struct HubCaliberAccountingData {
        uint256 netAum;
        bytes[] positions; // abi.encode(positionId, positionSize)
    }

    /// @notice Returns the accounting data of the associated caliber.
    /// @return data The accounting data.
    function getHubCaliberAccountingData() external view returns (HubCaliberAccountingData memory);
}
