// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICaliber} from "../../src/interfaces/ICaliber.sol";

import {MerkleTreeHelper} from "./MerkleTreeHelper.sol";

/// @dev Hashes instructions into leaves, builds a Merkle tree from them and serves its root and proofs.
abstract contract RootfileHelper is MerkleTreeHelper {
    error DuplicateLeaf();
    error UnknownLeaf();

    bytes32[] internal rootfileLeaves;

    mapping(bytes32 leaf => uint256 indexPlusOne) private _leafIndexes;

    function _addLeaf(ICaliber.Instruction memory template) internal {
        bytes32 leaf = _instructionLeaf(template);
        if (_leafIndexes[leaf] != 0) {
            revert DuplicateLeaf();
        }
        rootfileLeaves.push(leaf);
        _leafIndexes[leaf] = rootfileLeaves.length;
    }

    function _rootfileRoot() internal view returns (bytes32) {
        return _merkleRoot(rootfileLeaves);
    }

    function _withProof(ICaliber.Instruction memory instruction) internal view returns (ICaliber.Instruction memory) {
        instruction.merkleProof = _proofOf(instruction);
        return instruction;
    }

    function _proofOf(ICaliber.Instruction memory instruction) internal view returns (bytes32[] memory) {
        uint256 indexPlusOne = _leafIndexes[_instructionLeaf(instruction)];
        if (indexPlusOne == 0) {
            revert UnknownLeaf();
        }
        return _merkleProof(rootfileLeaves, indexPlusOne - 1);
    }

    function _instructionLeaf(ICaliber.Instruction memory instruction) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    abi.encode(
                        keccak256(abi.encodePacked(instruction.commands)),
                        _stateHash(instruction.state, instruction.stateBitmap),
                        instruction.stateBitmap,
                        instruction.positionId,
                        instruction.isDebt,
                        instruction.groupId,
                        keccak256(abi.encodePacked(instruction.affectedTokens)),
                        keccak256(abi.encodePacked(instruction.positionTokens)),
                        instruction.instructionType
                    )
                )
            )
        );
    }

    function _stateHash(bytes[] memory state, uint128 bitmap) private pure returns (bytes32) {
        if (bitmap == uint128(0)) {
            return bytes32(0);
        }
        bytes memory hashInput;
        for (uint256 i; i < state.length; ++i) {
            if (bitmap & (0x80000000000000000000000000000000 >> i) != 0) {
                hashInput = bytes.concat(hashInput, keccak256(state[i]));
            }
        }
        return keccak256(hashInput);
    }
}
