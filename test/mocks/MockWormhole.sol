// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.20;

import {ICoreBridge, GuardianSet, GuardianSignature, CoreBridgeVM} from "@wormhole/sdk/interfaces/ICoreBridge.sol";
import {BytesLib} from "../utils/BytesLib.sol";
import {WormholeQueryTestHelpers} from "../utils/WormholeQueryTestHelpers.sol";

// Adapted from https://github.com/wormhole-foundation/example-liquidity-layer/blob/main/evm/forge/modules/wormhole/MockWormhole.sol
// Modified for testing purposes with wormhole-solidity-sdk v1.1.0
contract MockWormhole is ICoreBridge {
    using BytesLib for bytes;

    uint256 private constant VM_VERSION_SIZE = 1;
    uint256 private constant VM_GUARDIAN_SET_SIZE = 4;
    uint256 private constant VM_SIGNATURE_COUNT_SIZE = 1;
    uint256 private constant VM_TIMESTAMP_SIZE = 4;
    uint256 private constant VM_NONCE_SIZE = 4;
    uint256 private constant VM_EMITTER_CHAIN_ID_SIZE = 2;
    uint256 private constant VM_EMITTER_ADDRESS_SIZE = 32;
    uint256 private constant VM_SEQUENCE_SIZE = 8;
    uint256 private constant VM_CONSISTENCY_LEVEL_SIZE = 1;
    uint256 private constant VM_SIZE_MINIMUM = VM_VERSION_SIZE + VM_GUARDIAN_SET_SIZE + VM_SIGNATURE_COUNT_SIZE
        + VM_TIMESTAMP_SIZE + VM_NONCE_SIZE + VM_EMITTER_CHAIN_ID_SIZE + VM_EMITTER_ADDRESS_SIZE + VM_SEQUENCE_SIZE
        + VM_CONSISTENCY_LEVEL_SIZE;

    uint256 private constant SIGNATURE_GUARDIAN_INDEX_SIZE = 1;
    uint256 private constant SIGNATURE_R_SIZE = 32;
    uint256 private constant SIGNATURE_S_SIZE = 32;
    uint256 private constant SIGNATURE_V_SIZE = 1;
    uint256 private constant SIGNATURE_SIZE_TOTAL =
        SIGNATURE_GUARDIAN_INDEX_SIZE + SIGNATURE_R_SIZE + SIGNATURE_S_SIZE + SIGNATURE_V_SIZE;

    mapping(address => uint64) public sequences;
    // Dictionary of VMs that must be mocked as invalid.
    mapping(bytes32 => bool) public invalidVMs;

    uint256 currentMsgFee;
    uint16 immutable wormholeChainId;
    uint256 immutable boundEvmChainId;

    constructor(uint16 initChainId, uint256 initEvmChainId) {
        wormholeChainId = initChainId;
        boundEvmChainId = initEvmChainId;
    }

    // -- publishing --

    function messageFee() external view returns (uint256) {
        return currentMsgFee;
    }

    function publishMessage(uint32 nonce, bytes memory payload, uint8 consistencyLevel)
        external
        payable
        returns (uint64 sequence)
    {
        require(msg.value == currentMsgFee, "invalid fee");
        sequence = sequences[msg.sender]++;
        emit LogMessagePublished(msg.sender, sequence, nonce, payload, consistencyLevel);
    }

    // -- verification --

    function parseAndVerifyVM(bytes calldata encodedVm)
        external
        view
        returns (CoreBridgeVM memory vm, bool valid, string memory reason)
    {
        vm = _parseVM(encodedVm);
        //behold the rigorous checking!
        valid = !invalidVMs[vm.hash];
        reason = "";
    }

    // -- getters --

    function chainId() external view returns (uint16) {
        return wormholeChainId;
    }

    function evmChainId() external view returns (uint256) {
        return boundEvmChainId;
    }

    function nextSequence(address emitter) external view returns (uint64) {
        return sequences[emitter];
    }

    function getGuardianSet(uint32 /*index*/ ) external pure override returns (GuardianSet memory) {
        address[] memory keys = new address[](1);
        keys[0] = WormholeQueryTestHelpers.DEVNET_GUARDIAN_ADDRESS;

        GuardianSet memory gset = GuardianSet({keys: keys, expirationTime: 999999999});
        return gset;
    }

    function getCurrentGuardianSetIndex() external pure returns (uint32) {
        return 0;
    }

    // -- internal --

    function _parseVM(bytes calldata encodedVm) internal pure returns (CoreBridgeVM memory vm) {
        require(encodedVm.length >= 0, "vm too small");

        bytes memory body;

        uint256 offset = 0;
        vm.version = encodedVm.toUint8(offset);
        offset += 1;

        vm.guardianSetIndex = encodedVm.toUint32(offset);
        offset += 4;

        (vm.signatures, offset) = _parseSignatures(encodedVm, offset);

        body = encodedVm[offset:];
        vm.timestamp = encodedVm.toUint32(offset);
        offset += 4;

        vm.nonce = encodedVm.toUint32(offset);
        offset += 4;

        vm.emitterChainId = encodedVm.toUint16(offset);
        offset += 2;

        vm.emitterAddress = encodedVm.toBytes32(offset);
        offset += 32;

        vm.sequence = encodedVm.toUint64(offset);
        offset += 8;

        vm.consistencyLevel = encodedVm.toUint8(offset);
        offset += 1;

        vm.payload = encodedVm[offset:];
        vm.hash = keccak256(abi.encodePacked(keccak256(body)));
    }

    function _parseSignatures(bytes calldata encodedVm, uint256 offset)
        internal
        pure
        returns (GuardianSignature[] memory signatures, uint256 offsetAfterParse)
    {
        uint256 sigCount = uint256(encodedVm.toUint8(offset));
        offset += 1;

        require(encodedVm.length >= (VM_SIZE_MINIMUM + sigCount * SIGNATURE_SIZE_TOTAL), "vm too small");

        signatures = new GuardianSignature[](sigCount);
        for (uint256 i = 0; i < sigCount; ++i) {
            uint8 guardianIndex = encodedVm.toUint8(offset);
            offset += 1;

            bytes32 r = encodedVm.toBytes32(offset);
            offset += 32;

            bytes32 s = encodedVm.toBytes32(offset);
            offset += 32;

            uint8 v = encodedVm.toUint8(offset);
            offset += 1;

            signatures[i] = GuardianSignature({
                r: r,
                s: s,
                // The hardcoded 27 comes from the base offset for public key recovery ids, public key type and network
                // used in ECDSA signatures for bitcoin and ethereum.
                // See https://bitcoin.stackexchange.com/a/5089
                v: v + 27,
                guardianIndex: guardianIndex
            });
        }

        return (signatures, offset);
    }
}
