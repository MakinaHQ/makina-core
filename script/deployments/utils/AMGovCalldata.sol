// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

// solhint-disable no-console, gas-custom-errors, reason-string

import {console} from "forge-std/console.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

/// @dev Privileged calls that a script either broadcasts or logs for a governance account to submit.
///      Alongside a call's raw calldata, the log carries its `AccessManager.schedule` wrapper, for roles with an
///      execution delay: once the delay has passed, the role holder submits the raw call to the target directly.
abstract contract AMGovCalldata {
    struct Call {
        string label;
        address target;
        bytes data;
    }

    function _logCall(Call memory call) internal pure {
        require(call.target != address(0), "AMGovCalldata: target is address(0)");

        console.log(call.label);
        console.log("Target:", call.target);
        console.log("Calldata:");
        console.logBytes(call.data);

        console.log("AccessManager schedule calldata:");
        console.logBytes(abi.encodeCall(IAccessManager.schedule, (call.target, call.data, 0)));

        console.log("");
    }
}
