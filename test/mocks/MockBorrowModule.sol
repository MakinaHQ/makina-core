// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev MockBorrowModule contract for testing use only
contract MockBorrowModule {
    using Math for uint256;
    using SafeERC20 for IERC20;

    IERC20 private _asset;
    mapping(address => uint256) private _grossDebt;

    uint256 private BPS_DIVIDER = 10_000;

    uint256 public rateBps;

    constructor(IERC20 asset_) {
        _asset = asset_;
        rateBps = BPS_DIVIDER;
    }

    function asset() public view returns (address) {
        return address(_asset);
    }

    function borrow(uint256 assets) public {
        address receiver = msg.sender;
        _grossDebt[receiver] += assets;
        _asset.safeTransfer(receiver, assets);
    }

    function repay(uint256 assets) public {
        address sender = msg.sender;
        _asset.safeTransferFrom(sender, address(this), assets);
        _grossDebt[sender] -= assets.mulDiv(BPS_DIVIDER, rateBps);
    }

    function debtOf(address user) public view returns (uint256) {
        return _grossDebt[user].mulDiv(rateBps, BPS_DIVIDER, Math.Rounding.Ceil);
    }

    function setRateBps(uint256 _rateBps) public {
        rateBps = _rateBps;
    }
}
