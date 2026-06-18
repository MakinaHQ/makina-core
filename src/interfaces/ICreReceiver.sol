// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

interface ICreReceiver is IERC165 {
    function onReport(bytes calldata metadata, bytes calldata report) external;
}
