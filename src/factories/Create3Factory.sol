// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "../libraries/Errors.sol";

/// Forked from 0xSequence (https://github.com/0xSequence/create3/blob/master/contracts/Create3.sol)
abstract contract Create3Factory {
    /// @dev The bytecode for a contract that proxies the creation of another contract.
    /// If this code is deployed using CREATE2 it can be used to decouple `creationCode` from the child contract address.
    ///
    /// The proxy bytecode constant encodes two parts:
    /// 1. **Init code** (first table): runs once at deployment, writes the runtime code to memory, and returns it.
    /// 2. **Runtime code** (second table): becomes the code stored on-chain; when executed, it forwards calldata and value into a CREATE.
    ///
    /// Initcode (runs once at deployment, writes runtime code to memory and returns it):
    /// ┌────────────┬───────────────────────┬──────────────────┬──────────────────────┐
    /// │ Opcode     │ Opcode + Arguments    │ Mnemonic         │ Stack View           │
    /// ├────────────┼───────────────────────┼──────────────────┼──────────────────────┤
    /// │ 0x67       │  0x67XXXXXXXXXXXXXXXX │ PUSH8 bytecode   │ bytecode             │
    /// │ 0x3d       │  0x3d                 │ RETURNDATASIZE   │ 0 bytecode           │
    /// │ 0x52       │  0x52                 │ MSTORE           │                      │
    /// │ 0x60       │  0x6008               │ PUSH1 08         │ 0x08                 │
    /// │ 0x60       │  0x6018               │ PUSH1 18         │ 0x18 0x08            │
    /// │ 0xf3       │  0xf3                 │ RETURN           │                      │
    /// └────────────┴───────────────────────┴──────────────────┴──────────────────────┘
    ///
    /// Runtime code (becomes the code stored on-chain, forwards calldata and value into CREATE):
    /// ┌────────────┬───────────────────────┬──────────────────┬──────────────────────┐
    /// │ Opcode     │ Opcode + Arguments    │ Mnemonic         │ Stack                │
    /// ├────────────┼───────────────────────┼──────────────────┼──────────────────────┤
    /// │ 0x36       │  0x36                 │ CALLDATASIZE     │ cds                  │
    /// │ 0x3d       │  0x3d                 │ RETURNDATASIZE   │ 0 cds                │
    /// │ 0x3d       │  0x3d                 │ RETURNDATASIZE   │ 0 0 cds              │
    /// │ 0x37       │  0x37                 │ CALLDATACOPY     │                      │
    /// │ 0x36       │  0x36                 │ CALLDATASIZE     │ cds                  │
    /// │ 0x3d       │  0x3d                 │ RETURNDATASIZE   │ 0 cds                │
    /// │ 0x34       │  0x34                 │ CALLVALUE        │ value 0 cds          │
    /// │ 0xf0       │  0xf0                 │ CREATE           │ newContract          │
    /// └────────────┴───────────────────────┴──────────────────┴──────────────────────┘
    bytes internal constant PROXY_BYTECODE = hex"67363d3d37363d34f03d5260086018f3";

    /// @dev keccak256 hash of `PROXY_BYTECODE`.
    bytes32 internal constant PROXY_BYTECODE_HASH = 0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;

    /// @notice Creates a new contract using CREATE3.
    /// @dev
    function _create3(bytes32 _saltDomain, bytes32 _salt, bytes memory _initCode) internal returns (address) {
        bytes memory _proxyInitcode = PROXY_BYTECODE;

        if (_salt == bytes32(0)) {
            revert Errors.ZeroSalt();
        }

        bytes32 nSalt = _computeNamespacedSalt(_saltDomain, _salt);

        address newContract = _computeAddress(nSalt);

        if (newContract.code.length != 0) {
            revert Errors.TargetAlreadyExists();
        }

        address proxy;
        assembly {
            proxy := create2(0, add(_proxyInitcode, 0x20), mload(_proxyInitcode), nSalt)
        }
        if (proxy == address(0)) {
            revert Errors.Create3ProxyDeploymentFailed();
        }

        (bool success,) = proxy.call(_initCode);
        if (!success || newContract.code.length == 0) {
            revert Errors.Create3ContractDeploymentFailed();
        }

        return newContract;
    }

    /// @notice Computes the resulting address of a contract deployed via CREATE3 from this factory, using address(this) and the given salt
    /// @dev The address creation formula is: keccak256(rlp([keccak256(0xff ++ address(this) ++ _salt ++ keccak256(initCode))[12:], 0x01]))
    function _computeAddress(bytes32 _namespacedSalt) internal view returns (address) {
        address proxy = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(this), _namespacedSalt, PROXY_BYTECODE_HASH))))
        );
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", proxy, hex"01")))));
    }

    /// @notice Computes a namespaced salt from a domain and user-provided salt.
    function _computeNamespacedSalt(bytes32 domain, bytes32 userSalt) internal pure returns (bytes32) {
        return keccak256(abi.encode(domain, userSalt));
    }
}
