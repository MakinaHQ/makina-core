// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IMailbox} from "../interfaces/IMailbox.sol";
import {ISpokeMachineMailbox} from "../interfaces/ISpokeMachineMailbox.sol";

contract SpokeMachineMailbox is Initializable, ISpokeMachineMailbox {
    address public machine;
    address public spokeCaliberMailbox;
    uint256 public spokeChainId;

    function initialize(address _machine, uint256 _spokeChainId) external initializer {
        machine = _machine;
        spokeChainId = _spokeChainId;
    }

    function setSpokeCaliberMailbox(address _spokeCaliberMailbox) external {
        if (spokeCaliberMailbox != address(0)) {
            revert SpokeCaliberMailboxAlreadySet();
        }
        spokeCaliberMailbox = _spokeCaliberMailbox;
    }

    /// @inheritdoc IMailbox
    function manageTransferFromMachineToCaliber(address token, uint256 amount) external override {}

    /// @inheritdoc IMailbox
    function manageTransferFromCaliberToMachine(address token, uint256 amount) external override {}
}
