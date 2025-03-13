// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {ICaliber} from "../interfaces/ICaliber.sol";
import {IMailbox} from "../interfaces/IMailbox.sol";
import {ISpokeCaliberMailbox} from "../interfaces/ISpokeCaliberMailbox.sol";

contract SpokeCaliberMailbox is Initializable, ISpokeCaliberMailbox {
    uint256 public immutable hubChainId;

    address public hubMachineMailbox;
    address public caliber;

    constructor(uint256 _hubChainId) {
        hubChainId = _hubChainId;
    }

    modifier onlyCaliber() {
        if (msg.sender != caliber) {
            revert NotCaliber();
        }
        _;
    }

    function initialize(address _hubMachineMailbox, address _caliber) external override initializer {
        hubMachineMailbox = _hubMachineMailbox;
        caliber = _caliber;
    }

    /// @inheritdoc ISpokeCaliberMailbox
    function getSpokeCaliberAccountingData() external view override returns (SpokeCaliberAccountingData memory data) {
        (data.netAum, data.positions, data.baseTokens) = ICaliber(caliber).getPositionsValues();
        // @TODO include totalReceivedFromHM and totalSentToHM
    }

    /// @inheritdoc IMailbox
    function manageTransferFromMachineToCaliber(address token, uint256 amount) external override {}

    /// @inheritdoc IMailbox
    function manageTransferFromCaliberToMachine(address token, uint256 amount) external override onlyCaliber {}
}
