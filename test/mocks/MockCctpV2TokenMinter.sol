// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MockERC20} from "./MockERC20.sol";
import {ICctpV2TokenMinter} from "src/interfaces/ICctpV2TokenMinter.sol";

/// @dev MockCctpV2TokenMinter contract for testing use only
contract MockCctpV2TokenMinter is ICctpV2TokenMinter {
    address private localTokenMessenger;
    mapping(uint32 remoteDomain => mapping(bytes32 remoteToken => address localToken)) private remoteToLocalTokens;

    modifier onlyLocalTokenMessenger() {
        if (msg.sender != localTokenMessenger) {
            revert();
        }
        _;
    }

    function getLocalToken(uint32 remoteDomain, bytes32 remoteToken) external view override returns (address) {
        return remoteToLocalTokens[remoteDomain][remoteToken];
    }

    function mint(
        uint32 sourceDomain,
        bytes32 burnToken,
        address recipientOne,
        address recipientTwo,
        uint256 amountOne,
        uint256 amountTwo
    ) external onlyLocalTokenMessenger returns (address) {
        address _mintToken = remoteToLocalTokens[sourceDomain][burnToken];

        MockERC20(_mintToken).mint(recipientOne, amountOne);

        if (amountTwo > 0) {
            MockERC20(_mintToken).mint(recipientTwo, amountTwo);
        }

        return _mintToken;
    }

    function burn(address burnToken, uint256 burnAmount) external onlyLocalTokenMessenger {
        MockERC20(burnToken).burn(address(this), burnAmount);
    }

    function setLocalTokenMessenger(address _localTokenMessenger) external {
        localTokenMessenger = _localTokenMessenger;
    }

    function setLocalToken(uint32 remoteDomain, bytes32 remoteToken, address localToken) external {
        remoteToLocalTokens[remoteDomain][remoteToken] = localToken;
    }
}
