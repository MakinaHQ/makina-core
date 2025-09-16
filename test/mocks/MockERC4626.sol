// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC4626, ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @dev MockERC4626 contract for testing use only
///      permissionless minting
contract MockERC4626 is ERC4626 {
    uint8 private immutable _offset;

    constructor(string memory name_, string memory symbol_, IERC20 asset_, uint8 offset_)
        ERC20(name_, symbol_)
        ERC4626(asset_)
    {
        _offset = offset_;
    }

    function _decimalsOffset() internal view virtual override returns (uint8) {
        return _offset;
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
}
