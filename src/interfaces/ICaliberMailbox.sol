// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineEndpoint} from "./IMachineEndpoint.sol";

interface ICaliberMailbox is IMachineEndpoint {
    error CaliberAlreadySet();
    error NotCaliber();
    error NotFactory();

    struct SpokeCaliberAccountingData {
        uint256 netAum;
        bytes[] positions; // abi.encode(positionId, value)
        bytes[] baseTokens; // abi.encode(token, value)
        bytes[] totalReceivedFromHM; // abi.encode(baseToken, amount)
        bytes[] totalSentToHM; // abi.encode(baseToken, amount)
    }

    /// @notice Initializer of the contract.
    /// @param machineEndpoint The address of the associated machine endpoint.
    function initialize(address machineEndpoint) external;

    /// @notice Address of the associated caliber.
    function caliber() external view returns (address);

    /// @notice Chain ID of the hub.
    function hubChainId() external view returns (uint256);

    /// @notice Returns the accounting data of the associated caliber.
    /// @return data The accounting data.
    function getSpokeCaliberAccountingData() external view returns (SpokeCaliberAccountingData memory);

    /// @notice Sets the associated caliber address.
    /// @param caliber The address of the associated caliber.
    function setCaliber(address caliber) external;
}
