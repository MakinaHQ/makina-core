// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IMachineShare is IERC20Metadata {
    error NotMachine();

    function machine() external view returns (address);

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
