// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMachineShare} from "../interfaces/IMachineShare.sol";

contract MachineShare is ERC20, Ownable2Step, IMachineShare {
    uint8 private immutable decimals_;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _initialMinter)
        ERC20(_name, _symbol)
        Ownable(_initialMinter)
    {
        decimals_ = _decimals;
    }

    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return decimals_;
    }

    function minter() public view override returns (address) {
        return owner();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}
