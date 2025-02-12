// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev MockBorrowModule contract for testing use only
contract MockBorrowModule {
    using Math for uint256;
    using SafeERC20 for IERC20;

    error RepayAmountExceedsDebt();

    IERC20 private _asset;
    mapping(address user => uint256 grossDebt) private _grossDebtOf;

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
        _grossDebtOf[receiver] += assets;
        _asset.safeTransfer(receiver, assets);
    }

    function repay(uint256 assets) public {
        address sender = msg.sender;
        _asset.safeTransferFrom(sender, address(this), assets);
        uint256 _grossDebtDelta = assets.mulDiv(BPS_DIVIDER, rateBps);
        if (_grossDebtDelta > _grossDebtOf[sender]) {
            revert RepayAmountExceedsDebt();
        }
        _grossDebtOf[sender] -= _grossDebtDelta;
    }

    function debtOf(address user) public view returns (uint256) {
        return _grossDebtOf[user].mulDiv(rateBps, BPS_DIVIDER, Math.Rounding.Ceil);
    }

    function setRateBps(uint256 _rateBps) public {
        rateBps = _rateBps;
    }
}
