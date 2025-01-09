// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

library WeirollPlanner {
    function buildCommand(bytes4 _selector, bytes1 _flags, bytes6 _input, bytes1 _output, address _target)
        internal
        pure
        returns (bytes32)
    {
        uint256 selector = uint256(bytes32(_selector));
        uint256 flags = uint256(uint8(_flags)) << 216;
        uint256 input = uint256(uint48(_input)) << 168;
        uint256 output = uint256(uint8(_output)) << 160;
        uint256 target = uint256(uint160(_target));

        return bytes32(selector ^ flags ^ input ^ output ^ target);
    }
}
