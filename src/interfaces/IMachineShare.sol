// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IMachineShare is IERC20Metadata {
    /// @notice Address of the authorized minter and burner.
    function minter() external view returns (address);

    /// @notice Mints new shares to the specified address.
    /// @param to The recipient of the minted shares.
    /// @param amount The amount of shares to mint.
    function mint(address to, uint256 amount) external;

    /// @notice Burns shares from the specified address.
    /// @param from The owner of the shares to burn.
    /// @param amount The amount of shares to burn.
    function burn(address from, uint256 amount) external;
}
