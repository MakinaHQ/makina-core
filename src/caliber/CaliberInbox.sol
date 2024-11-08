// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberInbox} from "../interfaces/ICaliberInbox.sol";

abstract contract CaliberInbox is Initializable, ICaliberInbox {
    using SafeERC20 for IERC20;

    address public override caliber;

    mapping(address token => uint256 pendingAmount) public pendingReceivedFromHubMachine;
    mapping(address baseToken => uint256 totalAmount) public totalReceivedFromHubMachine;
    mapping(address baseToken => uint256 totalAmount) public totalSentToHubMachine;

    address[] internal _pendingReceivedTokens;
    address[] internal _receivedTokens;
    address[] internal _sentTokens;

    constructor() {
        _disableInitializers();
    }

    function __caliberInbox_init(address _caliber) internal onlyInitializing {
        caliber = _caliber;
    }

    modifier onlyCaliber() {
        if (msg.sender != caliber) {
            revert NotCaliber();
        }
        _;
    }

    /// @inheritdoc ICaliberInbox
    function withdrawPendingReceivedAmounts() external override onlyCaliber {
        address _caliber = caliber;
        uint256 len = _pendingReceivedTokens.length;
        uint256 i;
        while (i < len) {
            address token = _pendingReceivedTokens[i];
            if (ICaliber(_caliber).isBaseToken(token)) {
                uint256 pendingAmount = pendingReceivedFromHubMachine[token];
                IERC20(token).safeTransfer(_caliber, pendingAmount);
                if (totalReceivedFromHubMachine[token] == 0) {
                    _receivedTokens.push(token);
                }
                totalReceivedFromHubMachine[token] += pendingAmount;
                pendingReceivedFromHubMachine[token] = 0;

                unchecked {
                    --len;
                }

                // swap element to remove with the last element and pop last element
                if (i != len) {
                    _pendingReceivedTokens[i] = _pendingReceivedTokens[len];
                }
                _pendingReceivedTokens.pop();
            } else {
                unchecked {
                    ++i;
                }
            }
        }
    }

    function _formatAccountingMessageSlim(uint256 _totalAccountingTokenValue, uint256 _lastAccountingTime)
        internal
        view
        returns (AccountingMessageSlim memory)
    {
        uint256 len = _receivedTokens.length;
        bytes[] memory _totalReceivedFromHM = new bytes[](len);
        for (uint256 i; i < len; i++) {
            address baseToken = _receivedTokens[i];
            _totalReceivedFromHM[i] = abi.encode(baseToken, totalReceivedFromHubMachine[baseToken]);
        }

        len = _sentTokens.length;
        bytes[] memory _totalSentToHM = new bytes[](len);
        for (uint256 i; i < len; i++) {
            address baseToken = _sentTokens[i];
            _totalSentToHM[i] = abi.encode(baseToken, totalSentToHubMachine[baseToken]);
        }

        return AccountingMessageSlim({
            lastAccountingTime: _lastAccountingTime,
            totalAccountingTokenValue: _totalAccountingTokenValue,
            totalReceivedFromHM: _totalReceivedFromHM,
            totalSentToHM: _totalSentToHM
        });
    }
}
