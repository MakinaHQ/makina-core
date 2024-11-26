// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev MockPool contract for testing use only
contract MockPool is ERC20 {
    using SafeERC20 for IERC20;

    error InvalidToken();

    address public token1;
    address public token2;

    constructor(address _token1, address _token2, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        token1 = _token1;
        token2 = _token2;
    }

    function addLiquidity(uint256 token1Amount, uint256 token2Amount) public returns (uint256) {
        IERC20(token1).safeTransferFrom(msg.sender, address(this), token1Amount);
        IERC20(token2).safeTransferFrom(msg.sender, address(this), token2Amount);
        uint256 lpTokenAmount = token1Amount + token2Amount;
        _mint(msg.sender, lpTokenAmount);
        return lpTokenAmount;
    }

    function removeLiquidity(uint256 lpTokenAmount) public returns (uint256, uint256) {
        uint256 totalSupply = totalSupply();
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));
        uint256 token2Balance = IERC20(token2).balanceOf(address(this));

        uint256 token1Amount = (lpTokenAmount * token1Balance) / totalSupply;
        uint256 token2Amount = (lpTokenAmount * token2Balance) / totalSupply;

        _burn(msg.sender, lpTokenAmount);

        IERC20(token1).safeTransferFrom(msg.sender, address(this), token1Amount);
        IERC20(token2).safeTransferFrom(msg.sender, address(this), token2Amount);

        return (token1Amount, token2Amount);
    }

    function swap(address tokenIn, uint256 amountIn) public {
        if (tokenIn != token1 && tokenIn != token2) {
            revert InvalidToken();
        }
        address tokenOut = (tokenIn == token1) ? token2 : token1;
        uint256 amountOut = _previewSwap(tokenIn, amountIn, tokenOut);
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
    }

    function previewSwap(address tokenIn, uint256 amountIn) public view returns (uint256) {
        if (tokenIn != token1 && tokenIn != token2) {
            revert InvalidToken();
        }
        address tokenOut = (tokenIn == token1) ? token2 : token1;
        return _previewSwap(tokenIn, amountIn, tokenOut);
    }

    function _previewSwap(address tokenIn, uint256 amountIn, address tokenOut) internal view returns (uint256) {
        return amountIn * IERC20(tokenOut).balanceOf(address(this)) / IERC20(tokenIn).balanceOf(address(this));
    }
}
