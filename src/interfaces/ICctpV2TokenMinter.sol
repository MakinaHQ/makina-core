// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ICctpV2TokenMinter {
    function getLocalToken(uint32 remoteDomain, bytes32 remoteToken) external view returns (address);
}
