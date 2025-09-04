// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @dev Misc utils for interacting with the CreateX Factory.
/// See https://github.com/pcaversaccio/createx/blob/main/src/CreateX.sol

interface ICreateX {
    function deployCreate3(bytes32 salt, bytes memory initCode) external payable returns (address newContract);
}

abstract contract CreateXUtils {
    address constant CREATE_X_DEPLOYER = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    function _formatSalt(bytes32 salt, address deployer) internal pure returns (bytes32) {
        bytes11 compressedSalt = bytes11(keccak256(abi.encode(salt)));
        return bytes32(abi.encodePacked(bytes20(deployer), bytes1(0), compressedSalt));
    }
}
