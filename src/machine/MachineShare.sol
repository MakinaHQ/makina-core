// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IMachineShare} from "../interfaces/IMachineShare.sol";
import {DecimalsUtils} from "../libraries/DecimalsUtils.sol";

contract MachineShare is ERC20, Ownable2Step, IMachineShare {
    constructor(string memory _name, string memory _symbol, address _initialMinter)
        ERC20(_name, _symbol)
        Ownable(_initialMinter)
    {}

    /// @inheritdoc IERC20Metadata
    function decimals() public pure override(ERC20, IERC20Metadata) returns (uint8) {
        return DecimalsUtils.SHARE_TOKEN_DECIMALS;
    }

    /// @inheritdoc IMachineShare
    function minter() external view override returns (address) {
        return owner();
    }

    /// @inheritdoc IMachineShare
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @inheritdoc IMachineShare
    function burn(address from, uint256 amount) external {
        if (from != msg.sender) {
            _checkOwner();
        }
        _burn(from, amount);
    }
}
