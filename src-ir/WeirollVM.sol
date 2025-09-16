// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.28;

import {VM} from "@enso-weiroll/VM.sol";
import {IWeirollVM} from "src/interfaces/IWeirollVM.sol";

contract WeirollVM is VM, IWeirollVM {
    /// @inheritdoc IWeirollVM
    function execute(bytes32[] calldata commands, bytes[] memory state) external returns (bytes[] memory r) {
        return _execute(commands, state);
    }
}
