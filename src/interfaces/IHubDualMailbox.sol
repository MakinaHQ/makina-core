// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineMailbox} from "./IMachineMailbox.sol";
import {ICaliberMailbox} from "./ICaliberMailbox.sol";

interface IHubDualMailbox is IMachineMailbox, ICaliberMailbox {
    error NotBaseToken();
}
