// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev MockSupplyModule contract for testing use only
contract MockSupplyModule {
    using Math for uint256;
    using SafeERC20 for IERC20;

    error WithdrawAmountExceedsCollateral();

    uint256 private constant BPS_DIVIDER = 10_000;

    IERC20 private _asset;
    mapping(address user => uint256 grossCollateral) private _collateralOf;

    bool public faultyMode;
    uint256 public rateBps;

    constructor(IERC20 asset_) {
        _asset = asset_;
        rateBps = BPS_DIVIDER;
    }

    function asset() public view returns (address) {
        return address(_asset);
    }

    function supply(uint256 assets) public {
        address sender = msg.sender;
        _asset.safeTransferFrom(sender, address(this), assets);
        if (faultyMode) {
            _collateralOf[sender] = _collateralOf[sender] > assets ? _collateralOf[sender] - assets : 0;
        } else {
            _collateralOf[sender] += assets;
        }
    }

    function withdraw(uint256 assets) public {
        address sender = msg.sender;
        if (assets > _collateralOf[sender]) {
            revert WithdrawAmountExceedsCollateral();
        }
        if (faultyMode) {
            _collateralOf[sender] += assets;
        } else {
            _collateralOf[sender] -= assets;
        }
        _asset.transfer(sender, assets);
    }

    function collateralOf(address user) public view returns (uint256) {
        return _collateralOf[user].mulDiv(rateBps, BPS_DIVIDER);
    }

    function setFaultyMode(bool _faultyMode) public {
        faultyMode = _faultyMode;
    }

    function setRateBps(uint256 _rateBps) public {
        rateBps = _rateBps;
    }
}
