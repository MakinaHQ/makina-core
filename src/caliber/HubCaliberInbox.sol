// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CaliberInbox, ICaliberInbox} from "./CaliberInbox.sol";

contract HubCaliberInbox is CaliberInbox {
    using SafeERC20 for IERC20;

    error NotHMInbox();

    /// @inheritdoc ICaliberInbox
    function initialize(address _caliber, address _hubMachineInbox) external override initializer {
        __caliberInbox_init(_caliber, _hubMachineInbox);
    }

    modifier onlyHMInbox() {
        if (msg.sender != hubMachineInbox) {
            revert NotHMInbox();
        }
        _;
    }

    /// @inheritdoc ICaliberInbox
    function notifyAmountFromHubMachine(address token, uint256 amount) external override onlyHMInbox {
        if (amount == 0) {
            return;
        }
        if (pendingReceivedFromHubMachine[token] == 0) {
            _pendingReceivedTokens.push(token);
        }
        pendingReceivedFromHubMachine[token] += amount;
        IERC20(token).safeTransferFrom(hubMachineInbox, address(this), amount);
    }

    /// @inheritdoc ICaliberInbox
    function initTransferToHubMachine(address token, uint256 amount) external override onlyCaliber {
        if (amount == 0) {
            return;
        }
        if (totalSentToHubMachine[token] == 0) {
            _sentTokens.push(token);
        }
        totalSentToHubMachine[token] += amount;
        // @TODO approve hubMachineInbox and notify it to pull the funds
        IERC20(token).safeTransferFrom(caliber, hubMachineInbox, amount);
    }

    /// @inheritdoc ICaliberInbox
    function relayAccounting(uint256 totalAccountingTokenValue)
        external
        onlyCaliber
        returns (AccountingMessageSlim memory)
    {
        // @TODO notify hubMachineInbox of the accounting message
        return _formatAccountingMessageSlim(totalAccountingTokenValue, block.timestamp);
    }
}
