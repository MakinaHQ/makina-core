// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ISwapper} from "../interfaces/ISwapper.sol";

interface ICaliber {
    error ActiveUpdatePending();
    error BaseTokenAlreadyExists();
    error BaseTokenPosition();
    error InvalidAccounting();
    error InvalidAffectedToken();
    error InvalidPositionChangeDirection();
    error InvalidInputLength();
    error InvalidInstructionsLength();
    error InvalidInstructionProof();
    error InvalidInstructionType();
    error InvalidOutputToken();
    error MaxValueLossExceeded();
    error NegativeTokenPrice();
    error NotBaseTokenPosition();
    error PositionAccountingStale(uint256 posId);
    error PositionAlreadyExists();
    error PositionDoesNotExist();
    error RecoveryMode();
    error TimelockDurationTooShort();
    error UnauthorizedOperator();
    error UnmatchingInstructions();
    error ZeroPositionId();

    event MailboxDeployed(address indexed mailbox);
    event MaxPositionDecreaseLossBpsChanged(
        uint256 indexed oldMaxPositionDecreaseLossBps, uint256 indexed newMaxPositionDecreaseLossBps
    );
    event MaxPositionIncreaseLossBpsChanged(
        uint256 indexed oldMaxPositionIncreaseLossBps, uint256 indexed newMaxPositionIncreaseLossBps
    );
    event MaxSwapLossBpsChanged(uint256 indexed oldMaxSwapLossBps, uint256 indexed newMaxSwapLossBps);
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event NewAllowedInstrRootScheduled(bytes32 indexed newMerkleRoot, uint256 indexed effectiveTime);
    event PositionClosed(uint256 indexed id);
    event PositionCreated(uint256 indexed id);
    event PositionStaleThresholdChanged(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    event RecoveryModeChanged(bool indexed enabled);
    event SecurityCouncilChanged(address indexed oldSecurityCouncil, address indexed newSecurityCouncil);
    event TimelockDurationChanged(uint256 indexed oldDuration, uint256 indexed newDuration);
    event TransferToHubMachine(address indexed token, uint256 amount);

    enum InstructionType {
        MANAGEMENT,
        ACCOUNTING,
        HARVEST
    }

    /// @notice Initialization parameters.
    /// @param hubMachineEndpoint The address of the hub machine endpoints.
    /// @param mailboxBeacon The address of the mailbox beacon.
    /// @param accountingToken The address of the accounting token.
    /// @param accountingTokenPosId The ID of the accounting token position.
    /// @param initialPositionStaleThreshold The position accounting staleness threshold in seconds.
    /// @param initialAllowedInstrRoot The root of the Merkle tree containing allowed instructions.
    /// @param initialTimelockDuration The duration of the allowedInstrRoot update timelock.
    /// @param initialMaxPositionIncreaseLossBps The max allowed value loss (in basis point) for position increases.
    /// @param initialMaxPositionDecreaseLossBps The max allowed value loss (in basis point) for position decreases.
    /// @param initialMaxSwapLossBps The max allowed value loss (in basis point) for base token swaps.
    /// @param initialMechanic The address of the initial mechanic.
    /// @param initialSecurityCouncil The address of the initial security council.
    /// @param initialAuthority The address of the initial authority.
    struct InitParams {
        address hubMachineEndpoint;
        address mailboxBeacon;
        address accountingToken;
        uint256 accountingTokenPosId;
        uint256 initialPositionStaleThreshold;
        bytes32 initialAllowedInstrRoot;
        uint256 initialTimelockDuration;
        uint256 initialMaxPositionIncreaseLossBps;
        uint256 initialMaxPositionDecreaseLossBps;
        uint256 initialMaxSwapLossBps;
        address initialMechanic;
        address initialSecurityCouncil;
        address initialAuthority;
    }

    /// @notice Instruction parameters.
    /// @param positionId The ID of the position concerned.
    /// @param isDebt Whether the position is a debt.
    /// @param instructionType The type of the instruction.
    /// @param affectedTokens The array of affected tokens.
    /// @param commands The array of commands.
    /// @param state The array of state.
    /// @param stateBitmap The state bitmap.
    /// @param merkleProof The array of Merkle proof elements.
    struct Instruction {
        uint256 positionId;
        bool isDebt;
        InstructionType instructionType;
        address[] affectedTokens;
        bytes32[] commands;
        bytes[] state;
        uint128 stateBitmap;
        bytes32[] merkleProof;
    }

    /// @notice Position data.
    /// @param lastAccountingTime The last block timestamp when the position was accounted for.
    /// @param value The value of the position expressed in accounting token.
    /// @param isBaseToken Is the position a base token.
    /// @param isDebt Whether the position is a debt.
    struct Position {
        uint256 lastAccountingTime;
        uint256 value;
        bool isBaseToken;
        bool isDebt;
    }

    /// @notice Initializer of the contract.
    /// @param params The initialization parameters.
    function initialize(InitParams calldata params) external;

    /// @notice Address of the Makina registry.
    function registry() external view returns (address);

    /// @notice Address of the mailbox.
    function mailbox() external view returns (address);

    /// @notice Address of the mechanic.
    function mechanic() external view returns (address);

    /// @notice Address of the security council.
    function securityCouncil() external view returns (address);

    /// @notice Address of the accounting token.
    function accountingToken() external view returns (address);

    /// @notice Caliber's AUM (expressed in accounting token) as of the last report to the hub machine.
    function lastReportedAUM() external view returns (uint256);

    /// @notice Timestamp of the last caliber's AUM report to the hub machine.
    function lastReportedAUMTime() external view returns (uint256);

    /// @notice Maximum duration a position can remain unaccounted for before it is considered stale.
    function positionStaleThreshold() external view returns (uint256);

    /// @notice Is the caliber in recovery mode.
    function recoveryMode() external view returns (bool);

    /// @notice Root of the Merkle tree containing allowed instructions.
    function allowedInstrRoot() external view returns (bytes32);

    /// @notice Duration of the allowedInstrRoot update timelock.
    function timelockDuration() external view returns (uint256);

    /// @notice Value of the pending allowedInstrRoot, if any.
    function pendingAllowedInstrRoot() external view returns (bytes32);

    /// @notice Effective time of the last scheduled allowedInstrRoot update.
    function pendingTimelockExpiry() external view returns (uint256);

    /// @notice Max allowed value loss (in basis point) when increasing a position.
    function maxPositionIncreaseLossBps() external view returns (uint256);

    /// @notice Max allowed value loss (in basis point) when decreasing a position.
    function maxPositionDecreaseLossBps() external view returns (uint256);

    /// @notice Max allowed value loss (in basis point) for base token swaps.
    function maxSwapLossBps() external view returns (uint256);

    /// @notice Length of the position IDs array.
    function getPositionsLength() external view returns (uint256);

    /// @dev Position index => Position ID
    /// @dev There are no guarantees on the ordering of values inside the Position ID array,
    ///      and it may change when values are added or remove.
    function getPositionId(uint256 idx) external view returns (uint256);

    /// @dev Position ID => Position data
    function getPosition(uint256 id) external view returns (Position memory);

    /// @dev Token => Registered as base token in this caliber
    function isBaseToken(address token) external view returns (bool);

    /// @dev Checks if the accounting age of each non-base-token position is below the position staleness threshold.
    function isAccountingFresh() external view returns (bool);

    /// @notice Adds a new base token.
    /// @param token The address of the base token.
    /// @param positionId The ID for the base token position.
    function addBaseToken(address token, uint256 positionId) external;

    /// @dev Accounts for a base token position.
    /// @param posId The ID of the base token position.
    /// @return value The new position value.
    /// @return change The change in the position value.
    function accountForBaseToken(uint256 posId) external returns (uint256 value, int256 change);

    /// @notice Accounts for a position.
    /// @dev If the position value goes to zero, it is closed.
    /// @param instruction The accounting instruction.
    /// @return value The new position value.
    /// @return change The change in the position value.
    function accountForPosition(Instruction calldata instruction) external returns (uint256 value, int256 change);

    /// @notice Accounts for a batch of positions.
    /// @dev If a position value reaches zero, it is closed, i.e. removed from storage.
    /// @param instructions The array of accounting instructions.
    function accountForPositionBatch(Instruction[] calldata instructions) external;

    /// @notice Updates and reports the caliber's AUM to the hub machine.
    /// @param instructions The array of accounting instructions to be performed before the AUM computation.
    function updateAndReportCaliberAUM(Instruction[] calldata instructions) external;

    /// @notice Gets the caliber's AUM and individual positions values.
    /// @return aum The caliber's AUM, i.e the total value of all positions.
    /// @return positionsValues The array of encoded tuples of the form (positionId, value, isDebt).
    function getPositionsValues() external view returns (uint256 aum, bytes[] memory positionsValues);

    /// @notice Manages a position's state through paired management and accounting instructions
    /// @dev Performs accounting updates and modifies contract storage by:
    /// - Adding new positions to storage when created.
    /// - Removing positions from storage when value reaches zero.
    /// @dev Applies value preservation checks using a validation matrix to prevent
    /// economic inconsistencies between position changes and token flows.
    ///
    /// The matrix evaluates three factors to determine required validations:
    /// - Base Token Inflow - Whether the contract's base token balance increases during operation
    /// - Debt Position - Whether position represents protocol liability (true) vs asset (false)
    /// - Position Δ direction - Direction of position value change (increase/decrease)
    ///
    /// ┌───────────────────┬───────────────┬──────────────────────┬───────────────────────────┐
    /// │ Base Token Inflow │ Debt Position │ Position Δ direction │ Action                    │
    /// ├───────────────────┼───────────────┼──────────────────────┼───────────────────────────┤
    /// │ No                │ No            │ Decrease             │ Revert: Invalid direction │
    /// │ No                │ Yes           │ Increase             │ Revert: Invalid direction │
    /// │ No                │ No            │ Increase             │ Minimum Δ Check           │
    /// │ No                │ Yes           │ Decrease             │ Minimum Δ Check           │
    /// │ Yes               │ No            │ Decrease             │ Maximum Δ Check           │
    /// │ Yes               │ Yes           │ Increase             │ Maximum Δ Check           │
    /// │ Yes               │ No            │ Increase             │ No check (favorable move) │
    /// │ Yes               │ Yes           │ Decrease             │ No check (favorable move) │
    /// └───────────────────┴───────────────┴──────────────────────┴───────────────────────────┘
    /// @param instructions The array containing paired management and accounting instructions.
    /// @return value The new position value.
    /// @return change The signed position value delta.
    function managePosition(Instruction[] calldata instructions) external returns (uint256 value, int256 change);

    /// @notice Harvests one or multiple positions.
    /// @param instruction The harvest instruction.
    /// @param swapOrders The array of swap orders to be executed after the harvest.
    function harvest(Instruction calldata instruction, ISwapper.SwapOrder[] calldata swapOrders) external;

    /// @notice Performs a swap via the swapper module.
    /// @param order The swap order parameters.
    function swap(ISwapper.SwapOrder calldata order) external;

    /// @notice Initiates a token transfer to the hub machine.
    /// @param token The address of the token to transfer.
    /// @param amount The amount of token to transfer.
    function transferToHubMachine(address token, uint256 amount) external;

    /// @notice Sets a new mechanic.
    /// @param newMechanic The address of new mechanic.
    function setMechanic(address newMechanic) external;

    /// @notice Sets a new security council.
    /// @param newSecurityCouncil The address of the new security council.
    function setSecurityCouncil(address newSecurityCouncil) external;

    /// @notice Sets the position accounting staleness threshold.
    /// @param newPositionStaleThreshold The new threshold in seconds.
    function setPositionStaleThreshold(uint256 newPositionStaleThreshold) external;

    /// @notice Sets the recovery mode.
    /// @param enabled True to enable recovery mode, false to disable.
    function setRecoveryMode(bool enabled) external;

    /// @notice Sets the duration of the allowedInstrRoot update timelock.
    /// @param newTimelockDuration The new duration in seconds.
    function setTimelockDuration(uint256 newTimelockDuration) external;

    /// @notice Schedules an update of the root of the Merkle tree containing allowed instructions.
    /// @dev The update will take effect after the timelock duration stored in the contract
    /// at the time of the call.
    /// @param newMerkleRoot The root of the Merkle tree containing allowed instructions.
    function scheduleAllowedInstrRootUpdate(bytes32 newMerkleRoot) external;

    /// @notice Sets the max allowed value loss for position increases.
    /// @param newMaxPositionIncreaseLossBps The new max value loss in basis points.
    function setMaxPositionIncreaseLossBps(uint256 newMaxPositionIncreaseLossBps) external;

    /// @notice Sets the max allowed value loss for position decreases.
    /// @param newMaxPositionDecreaseLossBps The new max value loss in basis points.
    function setMaxPositionDecreaseLossBps(uint256 newMaxPositionDecreaseLossBps) external;

    /// @notice Sets the max allowed value loss for base token swaps.
    /// @param newMaxSwapLossBps The new max value loss in basis points.
    function setMaxSwapLossBps(uint256 newMaxSwapLossBps) external;
}
