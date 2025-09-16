// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IMachineEndpoint} from "./IMachineEndpoint.sol";
import {IMakinaGovernable} from "./IMakinaGovernable.sol";

interface ICaliberMailbox is IMachineEndpoint {
    event CaliberSet(address indexed caliber);
    event HubBridgeAdapterSet(uint256 indexed bridgeId, address indexed adapter);

    /// @notice Accounting data of the caliber.
    /// @param netAum The net AUM expresses in caliber's accounting token.
    /// @param positions The list of positions of the caliber, each encoded as abi.encode(positionId, value, isDebt).
    /// @param baseTokens The list of base tokens of the caliber, each encoded as abi.encode(token, value).
    /// @param bridgesIn The list of incoming bridge amounts, each encoded as abi.encode(token, amount).
    /// @param bridgesOut The list of outgoing bridge amounts, each encoded as abi.encode(token, amount).
    struct SpokeCaliberAccountingData {
        uint256 netAum;
        bytes[] positions;
        bytes[] baseTokens;
        bytes[] bridgesIn;
        bytes[] bridgesOut;
    }

    /// @notice Initializer of the contract.
    /// @param mgParams The makina governable initialization parameters.
    /// @param hubMachine The foreign address of the hub machine.
    function initialize(IMakinaGovernable.MakinaGovernableInitParams calldata mgParams, address hubMachine) external;

    /// @notice Address of the associated caliber.
    function caliber() external view returns (address);

    /// @notice Returns the foreign address of the Hub bridge adapter for a given bridge ID.
    /// @param bridgeId The ID of the bridge.
    function getHubBridgeAdapter(uint16 bridgeId) external view returns (address);

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
    function setHubBridgeAdapter(uint16 bridgeId, address adapter) external;
}
