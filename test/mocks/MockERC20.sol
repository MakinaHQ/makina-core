// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev MockERC20 contract for testing use only
///      permissionless minting
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint256 decimals_) ERC20(name_, symbol_) {
        _decimals = uint8(decimals_);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Function to directly call _mint of ERC20 for minting "amount" number of mock tokens.
     *   See {ERC20-_mint}.
     */
    function mint(address receiver, uint256 amount) public {
        _mint(receiver, amount);
    }

    /**
     * @notice Function to directly call _burn of ERC20 for burning "amount" number of mock tokens.
     *   See {ERC20-_burn}.
     */
    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}
