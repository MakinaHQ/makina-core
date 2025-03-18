// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @dev MockERC20 contract for testing use only with support for:
///       - direct minting and burning of tokens
///       - reentrancy scheduling
contract MockERC20 is ERC20 {
    enum Type {
        No,
        Before,
        After
    }

    Type private _reenterType;
    address private _reenterTarget;
    bytes private _reenterData;

    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint256 decimals_) ERC20(name_, symbol_) {
        _decimals = uint8(decimals_);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
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

    /// @notice Function to schedule a reentrancy call to the target contract.
    function scheduleReenter(Type when, address target, bytes calldata data) external {
        _reenterType = when;
        _reenterTarget = target;
        _reenterData = data;
    }

    /// @notice Function to call the target contract.
    function functionCall(address target, bytes memory data) public returns (bytes memory) {
        return Address.functionCall(target, data);
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (_reenterType == Type.Before) {
            _reenterType = Type.No;
            functionCall(_reenterTarget, _reenterData);
        }
        super._update(from, to, amount);
        if (_reenterType == Type.After) {
            _reenterType = Type.No;
            functionCall(_reenterTarget, _reenterData);
        }
    }
}
