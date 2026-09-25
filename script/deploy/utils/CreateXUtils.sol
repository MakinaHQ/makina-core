// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @dev Misc utils for interacting with the CreateX Factory.
/// See https://github.com/pcaversaccio/createx/blob/main/src/CreateX.sol

interface ICreateXMinimal {
    function deployCreate2(bytes32 salt, bytes memory initCode) external payable returns (address newContract);
    function deployCreate3(bytes32 salt, bytes memory initCode) external payable returns (address newContract);
    function computeCreate2Address(bytes32 salt, bytes32 initCodeHash) external view returns (address computedAddress);
    function computeCreate3Address(bytes32 salt) external view returns (address computedAddress);
}

abstract contract CreateXUtils {
    address public constant CREATE_X_DEPLOYER = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    /// @dev CreateX only binds a salt to its sender when the first 20 bytes are the sender's address. A zero prefix
    ///      is guarded as a permissionless salt, whose address anyone could squat, so it is rejected upfront.
    function _formatSalt(bytes32 salt, address deployer) internal pure returns (bytes32) {
        require(deployer != address(0), "CreateXUtils: zero deployer");

        bytes11 compressedSalt = bytes11(keccak256(abi.encode(salt)));
        return bytes32(abi.encodePacked(bytes20(deployer), bytes1(0), compressedSalt));
    }

    /// @dev Address at which `_deployCodeCreateX` lands `bytecode` for `deployer`. CreateX guards a deployer-prefixed
    ///      salt without cross-chain protection as `keccak256(abi.encode(deployer, salt))` before deriving the address.
    function _computeCreateXAddress(bytes memory bytecode, bytes32 salt, address deployer)
        internal
        view
        returns (address)
    {
        bytes32 guardedSalt = keccak256(abi.encode(deployer, _formatSalt(salt, deployer)));

        if (salt == 0) {
            return ICreateXMinimal(CREATE_X_DEPLOYER).computeCreate2Address(guardedSalt, keccak256(bytecode));
        }

        return ICreateXMinimal(CREATE_X_DEPLOYER).computeCreate3Address(guardedSalt);
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
