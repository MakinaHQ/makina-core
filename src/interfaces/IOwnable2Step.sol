// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IOwnable2Step {
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function acceptOwnership() external;
}
