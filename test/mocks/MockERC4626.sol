// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC4626, ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev MockERC4626 contract for testing use only
///      permissionless minting
contract MockERC4626 is ERC4626 {
    error AccountingDisabled();

    uint8 private immutable _offset;

    bool public accountingDisabled;

    constructor(string memory name_, string memory symbol_, IERC20 asset_, uint8 offset_)
        ERC20(name_, symbol_)
        ERC4626(asset_)
    {
        _offset = offset_;
    }

    modifier whenAccountingEnabled() {
        if (accountingDisabled) {
            revert AccountingDisabled();
        }
        _;
    }

    function _decimalsOffset() internal view virtual override returns (uint8) {
        return _offset;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        override
        whenAccountingEnabled
        returns (uint256)
    {
        return super._convertToShares(assets, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        override
        whenAccountingEnabled
        returns (uint256)
    {
        return super._convertToAssets(shares, rounding);
    }

    /// @notice Function to directly call _mint of ERC20 for minting "amount" number of mock tokens.
    /// See {ERC20-_mint}.
    function mint(address receiver, uint256 amount) public {
        _mint(receiver, amount);
    }

    /// @notice Function to directly call _burn of ERC20 for burning "amount" number of mock tokens.
    /// See {ERC20-_burn}.
    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function setAccountingDisabled(bool _accountingDisabled) public {
        accountingDisabled = _accountingDisabled;
    }
}
