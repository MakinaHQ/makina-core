// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICaliber} from "../interfaces/ICaliber.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IHubDualMailbox} from "../interfaces/IHubDualMailbox.sol";
import {IMailbox} from "../interfaces/IMailbox.sol";

contract HubDualMailbox is Initializable, IHubDualMailbox {
    using SafeERC20 for IERC20;

    address public machine;
    address public caliber;

    function initialize(address _machine, address _caliber) external override initializer {
        machine = _machine;
        caliber = _caliber;
    }

    modifier onlyMachine() {
        if (msg.sender != machine) {
            revert NotMachine();
        }
        _;
    }

    modifier onlyCaliber() {
        if (msg.sender != caliber) {
            revert NotCaliber();
        }
        _;
    }

    /// @inheritdoc IMailbox
    function manageTransferFromMachineToCaliber(address token, uint256 amount) external override onlyMachine {
        if (!ICaliber(caliber).isBaseToken(token)) {
            revert NotBaseToken();
        }
        IERC20(token).safeTransferFrom(machine, caliber, amount);
    }

    /// @inheritdoc IMailbox
    function manageTransferFromCaliberToMachine(address token, uint256 amount) external override onlyCaliber {
        IERC20(token).safeTransferFrom(caliber, machine, amount);
        IMachine(machine).notifyIncomingTransfer(token);
    }

    /// @inheritdoc IHubDualMailbox
    function getHubCaliberAccountingData() external view override returns (HubCaliberAccountingData memory data) {
        (data.netAum, data.positions, data.baseTokens) = ICaliber(caliber).getPositionsValues();
    }
}
