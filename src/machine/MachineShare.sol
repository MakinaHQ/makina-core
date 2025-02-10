// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMachineShare} from "../interfaces/IMachineShare.sol";

contract MachineShare is ERC20, IMachineShare {
    address public immutable machine;
    uint8 private immutable decimals_;

    modifier onlyMachine() {
        if (msg.sender != machine) {
            revert NotMachine();
        }
        _;
    }

    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol) {
        machine = msg.sender;
        decimals_ = _decimals;
    }

    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return decimals_;
    }

    function mint(address to, uint256 amount) public onlyMachine {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyMachine {
        _burn(from, amount);
    }
}
