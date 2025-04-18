// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "./IBridgeAdapter.sol";
import {IMachineEndpoint} from "./IMachineEndpoint.sol";

interface ICaliberMailbox is IMachineEndpoint {
    error CaliberAlreadySet();
    error HubBridgeAdapterAlreadySet();
    error HubBridgeAdapterNotSet();
    error NotFactory();
    error UnauthorizedCaller();
    error ZeroBridgeAdapterAddress();

    event CaliberSet(address indexed caliber);
    event HubBridgeAdapterSet(uint256 indexed bridgeId, address indexed adapter);
    event ResetBridgeCounters(address indexed token);

    struct SpokeCaliberAccountingData {
        uint256 netAum;
        bytes[] positions; // abi.encode(positionId, value)
        bytes[] baseTokens; // abi.encode(token, value)
        bytes[] bridgesIn; // abi.encode(token, amount)
        bytes[] bridgesOut; // abi.encode(token, amount)
    }

    /// @notice Initializer of the contract.
    /// @param hubMachine The foreign address of the hub machine.
    /// @param initialAuthority The address of the initial authority.
    function initialize(address hubMachine, address initialAuthority) external;

    /// @notice Address of the associated caliber.
    function caliber() external view returns (address);

    /// @notice Returns the foreign address of the Hub bridge adapter for a given bridge ID.
    /// @param bridgeId The ID of the bridge.
    function getHubBridgeAdapter(IBridgeAdapter.Bridge bridgeId) external view returns (address);

    /// @notice Chain ID of the hub.
    function hubChainId() external view returns (uint256);

    /// @notice Returns the accounting data of the associated caliber.
    /// @return data The accounting data.
    function getSpokeCaliberAccountingData() external view returns (SpokeCaliberAccountingData memory);

    /// @notice Sets the associated caliber address.
    /// @param caliber The address of the associated caliber.
    function setCaliber(address caliber) external;

    /// @notice Registers a hub bridge adapter.
    /// @param bridgeId The ID of the bridge.
    /// @param adapter The foreign address of the bridge adapter.
    function setHubBridgeAdapter(IBridgeAdapter.Bridge bridgeId, address adapter) external;

    /// @notice Resets internal bridge counters for a given token when necessary to maintain protocol consistency.
    /// @dev This function is intended to be used by the DAO to realign bridge accounting state, typically
    /// in response to operator deviations, external bridge discrepancies, or unbounded counter growth.
    /// @param token The address of the token.
    function resetBridgeCounters(address token) external;
}
