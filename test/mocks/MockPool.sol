// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev MockPool contract for testing use only
contract MockPool is ERC20 {
    using SafeERC20 for IERC20;

    error InvalidToken();

    address public token0;
    address public token1;

    constructor(address _token0, address _token1, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        token0 = _token0;
        token1 = _token1;
    }

    function addLiquidity(uint256 token0Amount, uint256 token1Amount) public returns (uint256) {
        IERC20(token0).safeTransferFrom(msg.sender, address(this), token0Amount);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), token1Amount);
        uint256 lpTokenAmount = previewAddLiquidity(token0Amount, token1Amount);
        _mint(msg.sender, lpTokenAmount);
        return lpTokenAmount;
    }

    function addLiquidityOneSide(uint256 tokenAmount, address tokenIn) public returns (uint256) {
        if (tokenIn != token0 && tokenIn != token1) {
            revert InvalidToken();
        }
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenAmount);
        uint256 lpTokenAmount = previewAddLiquidityOneSide(tokenAmount, tokenIn);
        _mint(msg.sender, lpTokenAmount);
        return lpTokenAmount;
    }

    function removeLiquidity(uint256 lpTokenAmount) public returns (uint256, uint256) {
        (uint256 token0Amount, uint256 token1Amount) = previewRemoveLiquidity(lpTokenAmount);

        _burn(msg.sender, lpTokenAmount);

        IERC20(token0).safeTransferFrom(msg.sender, address(this), token0Amount);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), token1Amount);

        return (token0Amount, token1Amount);
    }

    function removeLiquidityOneSide(uint256 lpTokenAmount, address tokenOut) public returns (uint256) {
        uint256 tokenAmount = previewRemoveLiquidityOneSide(lpTokenAmount, tokenOut);

        _burn(msg.sender, lpTokenAmount);

        IERC20(tokenOut).safeTransfer(msg.sender, tokenAmount);

        return tokenAmount;
    }

    function swap(address tokenIn, uint256 amountIn) public {
        if (tokenIn != token0 && tokenIn != token1) {
            revert InvalidToken();
        }
        address tokenOut = (tokenIn == token0) ? token1 : token0;
        uint256 amountOut = _previewSwap(tokenIn, amountIn, tokenOut);
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
    }

    function previewAddLiquidity(uint256 token0Amount, uint256 token1Amount) public pure returns (uint256) {
        return token0Amount + token1Amount;
    }

    function previewAddLiquidityOneSide(uint256 tokenAmount, address /*tokenIn*/ ) public pure returns (uint256) {
        return tokenAmount;
    }

    function previewRemoveLiquidity(uint256 lpTokenAmount) public view returns (uint256, uint256) {
        uint256 totalSupply = totalSupply();
        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));

        uint256 token0Amount = (lpTokenAmount * token0Balance) / totalSupply;
        uint256 token1Amount = (lpTokenAmount * token1Balance) / totalSupply;

        return (token0Amount, token1Amount);
    }

    function previewRemoveLiquidityOneSide(uint256 lpTokenAmount, address tokenOut) public view returns (uint256) {
        if (tokenOut != token0 && tokenOut != token1) {
            revert InvalidToken();
        }
        if (lpTokenAmount == 0) {
            return 0;
        }

        uint256 totalSupply = totalSupply();
        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));

        uint256 totalPoolValue = token0Balance + token1Balance;
        uint256 lpTokenValue = (lpTokenAmount * totalPoolValue) / totalSupply;

        if (tokenOut == token0) {
            return (lpTokenValue * token0Balance) / totalPoolValue;
        } else {
            return (lpTokenValue * token1Balance) / totalPoolValue;
        }
    }

    function previewSwap(address tokenIn, uint256 amountIn) public view returns (uint256) {
        if (tokenIn != token0 && tokenIn != token1) {
            revert InvalidToken();
        }
        address tokenOut = (tokenIn == token0) ? token1 : token0;
        return _previewSwap(tokenIn, amountIn, tokenOut);
    }

    function _previewSwap(address tokenIn, uint256 amountIn, address tokenOut) internal view returns (uint256) {
        return amountIn * IERC20(tokenOut).balanceOf(address(this)) / IERC20(tokenIn).balanceOf(address(this));
    }
}
