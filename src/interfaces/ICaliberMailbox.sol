// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMachineEndpoint} from "./IMachineEndpoint.sol";
import {IMakinaGovernable} from "./IMakinaGovernable.sol";

interface ICaliberMailbox is IMachineEndpoint {
    event CaliberSet(address indexed caliber);
    event CooldownDurationChanged(uint256 oldDuration, uint256 newDuration);
    event HubBridgeAdapterSet(uint256 indexed bridgeId, address indexed adapter);

    /// @notice Spoke caliber accounting snapshot metadata.
    /// @param chainId The chain ID of the spoke caliber.
    /// @param mailbox The address of the spoke caliber mailbox.
    /// @param blockNum The block number used as the snapshot reference point.
    /// @param blockTime The block timestamp used as the snapshot reference point.
    struct SpokeSnapshotMeta {
        uint256 chainId;
        address mailbox;
        uint64 blockNum;
        uint256 blockTime;
    }

    /// @notice Spoke caliber accounting snapshot data.
    /// @param netAum The net AUM denominated in the caliber accounting token.
    /// @param bridgesIn The list of incoming bridge amounts, each encoded as abi.encode(token, amount).
    /// @param bridgesOut The list of outgoing bridge amounts, each encoded as abi.encode(token, amount).
    /// @param meta The snapshot metadata.
    struct SpokeCaliberAccountingData {
        uint256 netAum;
        bytes[] bridgesIn;
        bytes[] bridgesOut;
        SpokeSnapshotMeta meta;
    }

    /// @notice Initializer of the contract.
    /// @param mgParams The makina governable initialization parameters.
    /// @param initialCooldownDuration The duration of the cooldown period for outgoing bridge transfers.
    function initialize(IMakinaGovernable.MakinaGovernableInitParams calldata mgParams, uint256 initialCooldownDuration)
        external;

    /// @notice Address of the associated caliber.
    function caliber() external view returns (address);

    /// @notice Duration of the cooldown period for outgoing bridge transfers.
    function cooldownDuration() external view returns (uint256);

    /// @notice Returns the address of the hub bridge adapter for a given bridge ID.
    /// @param bridgeId The ID of the bridge.
    function getHubBridgeAdapter(uint16 bridgeId) external view returns (address);

    /// @notice Chain ID of the hub.
    function hubChainId() external view returns (uint256);

    /// @notice Returns the accounting data of the associated caliber.
    /// @return data The accounting data.
    function getSpokeCaliberAccountingData() external view returns (SpokeCaliberAccountingData memory);

    /// @notice Sets the associated caliber address.
    /// @param _caliber The address of the associated caliber.
    function setCaliber(address _caliber) external;

    /// @notice Sets the duration of the cooldown period for outgoing bridge transfers.
    /// @param newCooldownDuration The new duration in seconds.
    function setCooldownDuration(uint256 newCooldownDuration) external;

    /// @notice Registers a hub bridge adapter.
    /// @param bridgeId The ID of the bridge.
    /// @param adapter The address of the hub bridge adapter.
    function setHubBridgeAdapter(uint16 bridgeId, address adapter) external;
}
