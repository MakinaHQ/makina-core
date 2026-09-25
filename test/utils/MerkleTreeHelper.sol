// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @dev Computes Merkle roots and proofs over a set of leaves.
abstract contract MerkleTreeHelper {
    function _merkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        bytes32[] memory level = _padLeaves(leaves);
        while (level.length > 1) {
            level = _levelUp(level);
        }
        return level[0];
    }

    function _merkleProof(bytes32[] memory leaves, uint256 index) internal pure returns (bytes32[] memory proof) {
        bytes32[] memory level = _padLeaves(leaves);
        uint256 depth;
        for (uint256 len = level.length; len > 1; len >>= 1) {
            ++depth;
        }
        proof = new bytes32[](depth);
        for (uint256 i; i < depth; ++i) {
            proof[i] = level[index ^ 1];
            index >>= 1;
            level = _levelUp(level);
        }
    }

    /// @dev Pads to a power of two so every node has a sibling and every proof has the same depth.
    function _padLeaves(bytes32[] memory leaves) private pure returns (bytes32[] memory padded) {
        uint256 size = 1;
        while (size < leaves.length) {
            size <<= 1;
        }
        padded = new bytes32[](size);
        for (uint256 i; i < size; ++i) {
            padded[i] = i < leaves.length ? leaves[i] : keccak256(abi.encode("makina-core.filler", i));
        }
    }

    function _levelUp(bytes32[] memory level) private pure returns (bytes32[] memory up) {
        up = new bytes32[](level.length / 2);
        for (uint256 i; i < up.length; ++i) {
            (bytes32 a, bytes32 b) = (level[2 * i], level[2 * i + 1]);
            up[i] = a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
        }
    }
}
