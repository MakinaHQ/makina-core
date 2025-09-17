// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @dev Misc utils for interacting with the CreateX Factory.
/// See https://github.com/pcaversaccio/createx/blob/main/src/CreateX.sol

interface ICreateXMinimal {
    function deployCreate2(bytes32 salt, bytes memory initCode) external payable returns (address newContract);
    function deployCreate3(bytes32 salt, bytes memory initCode) external payable returns (address newContract);
}

abstract contract CreateXUtils {
    address public constant CREATE_X_DEPLOYER = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    function _formatSalt(bytes32 salt, address deployer) internal pure returns (bytes32) {
        bytes11 compressedSalt = bytes11(keccak256(abi.encode(salt)));
        return bytes32(abi.encodePacked(bytes20(deployer), bytes1(0), compressedSalt));
    }

    function _deployCodeCreateX(bytes memory bytecode, bytes32 salt, address deployer)
        internal
        virtual
        returns (address)
    {
        bytes32 formattedSalt = _formatSalt(salt, deployer);

        if (salt == 0) {
            return ICreateXMinimal(CREATE_X_DEPLOYER).deployCreate2(formattedSalt, bytecode);
        }

        return ICreateXMinimal(CREATE_X_DEPLOYER).deployCreate3(formattedSalt, bytecode);
    }
}
