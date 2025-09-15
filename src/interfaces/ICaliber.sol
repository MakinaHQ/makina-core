// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISwapModule} from "./ISwapModule.sol";

interface ICaliber {
    event BaseTokenAdded(address indexed token);
    event BaseTokenRemoved(address indexed token);
    event CooldownDurationChanged(uint256 indexed oldDuration, uint256 indexed newDuration);
    event IncomingTransfer(address indexed token, uint256 amount);
    event InstrRootGuardianAdded(address indexed newGuardian);
    event InstrRootGuardianRemoved(address indexed guardian);
    event MaxPositionDecreaseLossBpsChanged(
        uint256 indexed oldMaxPositionDecreaseLossBps, uint256 indexed newMaxPositionDecreaseLossBps
    );
    event MaxPositionIncreaseLossBpsChanged(
        uint256 indexed oldMaxPositionIncreaseLossBps, uint256 indexed newMaxPositionIncreaseLossBps
    );
    event MaxSwapLossBpsChanged(uint256 indexed oldMaxSwapLossBps, uint256 indexed newMaxSwapLossBps);
    event NewAllowedInstrRootCancelled(bytes32 indexed cancelledMerkleRoot);
    event NewAllowedInstrRootScheduled(bytes32 indexed newMerkleRoot, uint256 indexed effectiveTime);
    event PositionClosed(uint256 indexed id);
    event PositionCreated(uint256 indexed id, uint256 value);
    event PositionUpdated(uint256 indexed id, uint256 value);
    event PositionStaleThresholdChanged(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    event TimelockDurationChanged(uint256 indexed oldDuration, uint256 indexed newDuration);
    event TransferToHubMachine(address indexed token, uint256 amount);

    enum InstructionType {
        MANAGEMENT,
        ACCOUNTING,
        HARVEST,
        FLASHLOAN_MANAGEMENT
    }

    /// @notice Initialization parameters.
    /// @param initialPositionStaleThreshold The position accounting staleness threshold in seconds.
    /// @param initialAllowedInstrRoot The root of the Merkle tree containing allowed instructions.
    /// @param initialTimelockDuration The duration of the allowedInstrRoot update timelock.
    /// @param initialMaxPositionIncreaseLossBps The max allowed value loss (in basis point) for position increases.
    /// @param initialMaxPositionDecreaseLossBps The max allowed value loss (in basis point) for position decreases.
    /// @param initialMaxSwapLossBps The max allowed value loss (in basis point) for base token swaps.
    /// @param initialCooldownDuration The duration of the cooldown period for swaps and position management.
    struct CaliberInitParams {
        uint256 initialPositionStaleThreshold;
        bytes32 initialAllowedInstrRoot;
        uint256 initialTimelockDuration;
        uint256 initialMaxPositionIncreaseLossBps;
        uint256 initialMaxPositionDecreaseLossBps;
        uint256 initialMaxSwapLossBps;
        uint256 initialCooldownDuration;
    }

    /// @notice Instruction parameters.
    /// @param positionId The ID of the involved position.
    /// @param isDebt Whether the position is a debt.
    /// @param groupId The ID of the position accounting group.
    ///        Set to 0 if the instruction is not of type ACCOUNTING, or if the involved position is ungrouped.
    /// @param instructionType The type of the instruction.
    /// @param affectedTokens The array of affected tokens.
    /// @param commands The array of commands.
    /// @param state The array of state.
    /// @param stateBitmap The state bitmap.
    /// @param merkleProof The array of Merkle proof elements.
    struct Instruction {
        uint256 positionId;
        bool isDebt;
        uint256 groupId;
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
    /// @param isDebt Whether the position is a debt.
    struct Position {
        uint256 lastAccountingTime;
        uint256 value;
        bool isDebt;
    }

    /// @notice Initializer of the contract.
    /// @param cParams The caliber initialization parameters.
    /// @param _accountingToken The address of the accounting token.
    /// @param _hubMachineEndpoint The address of the hub machine endpoints.
    function initialize(CaliberInitParams calldata cParams, address _accountingToken, address _hubMachineEndpoint)
        external;

    /// @notice Address of the Weiroll VM.
    function weirollVm() external view returns (address);

    /// @notice Address of the hub machine endpoint.
    function hubMachineEndpoint() external view returns (address);

    /// @notice Address of the accounting token.
    function accountingToken() external view returns (address);

    /// @notice Maximum duration a position can remain unaccounted for before it is considered stale.
    function positionStaleThreshold() external view returns (uint256);

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

    /// @notice Duration of the cooldown period for swaps and position management.
    function cooldownDuration() external view returns (uint256);

    /// @notice Length of the position IDs list.
    function getPositionsLength() external view returns (uint256);

    /// @notice Position index => Position ID
    /// @dev There are no guarantees on the ordering of values inside the Position ID list,
    ///      and it may change when values are added or removed.
    function getPositionId(uint256 idx) external view returns (uint256);

    /// @notice Position ID => Position data
    function getPosition(uint256 id) external view returns (Position memory);

    /// @notice Token => Registered as base token in this caliber
    function isBaseToken(address token) external view returns (bool);

    /// @notice Length of the base tokens list.
    function getBaseTokensLength() external view returns (uint256);

    /// @notice Base token index => Base token address
    /// @dev There are no guarantees on the ordering of values inside the base tokens list,
    ///      and it may change when values are added or removed.
    function getBaseToken(uint256 idx) external view returns (address);

    /// @notice User => Whether the user is a root guardian
    ///      Guardians have veto power over updates of the Merkle root.
    function isInstrRootGuardian(address user) external view returns (bool);

    /// @notice Checks if the accounting age of each position is below the position staleness threshold.
    function isAccountingFresh() external view returns (bool);

    /// @notice Returns the caliber's net AUM along with detailed position and base token breakdowns.
    /// @return netAum The total value of all base token balances and positive positions, minus total debts.
    /// @return positions The array of encoded tuples of the form (positionId, value, isDebt).
    /// @return baseTokens The array of encoded tuples of the form (token, value).
    function getDetailedAum()
        external
        view
        returns (uint256 netAum, bytes[] memory positions, bytes[] memory baseTokens);

    /// @notice Adds a new base token.
    /// @param token The address of the base token.
    function addBaseToken(address token) external;

    /// @notice Removes a base token.
    /// @param token The address of the base token.
    function removeBaseToken(address token) external;

    /// @notice Accounts for a position.
    /// @dev If the position value goes to zero, it is closed.
    /// @param instruction The accounting instruction.
    /// @return value The new position value.
    /// @return change The change in the position value.
    function accountForPosition(Instruction calldata instruction) external returns (uint256 value, int256 change);

    /// @notice Accounts for a batch of positions.
    /// @param instructions The array of accounting instructions.
    /// @param groupIds The array of position group IDs.
    ///        An accounting instruction must be provided for every open position in each specified group.
    ///        If an instruction's groupId corresponds to a group of open positions of size greater than 1,
    ///        the group ID must be included in this array.
    /// @return values The new position values.
    /// @return changes The changes in the position values.
    function accountForPositionBatch(Instruction[] calldata instructions, uint256[] calldata groupIds)
        external
        returns (uint256[] memory values, int256[] memory changes);

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
    /// @param mgmtInstruction The management instruction.
    /// @param acctInstruction The accounting instruction.
    /// @return value The new position value.
    /// @return change The signed position value delta.
    function managePosition(Instruction calldata mgmtInstruction, Instruction calldata acctInstruction)
        external
        returns (uint256 value, int256 change);

    /// @notice Manages a batch of positions.
    /// @dev Convenience function to manage multiple positions in a single transaction.
    /// @param mgmtInstructions The array of management instructions.
    /// @param acctInstructions The array of accounting instructions.
    /// @return values The new position values.
    /// @return changes The changes in the position values.
    function managePositionBatch(Instruction[] calldata mgmtInstructions, Instruction[] calldata acctInstructions)
        external
        returns (uint256[] memory values, int256[] memory changes);

    /// @notice Manages flashLoan funds.
    /// @param instruction The flashLoan management instruction.
    /// @param token The loan token.
    /// @param amount The loan amount.
    function manageFlashLoan(Instruction calldata instruction, address token, uint256 amount) external;

    /// @notice Harvests one or multiple positions.
    /// @param instruction The harvest instruction.
    /// @param swapOrders The array of swap orders to be executed after the harvest.
    function harvest(Instruction calldata instruction, ISwapModule.SwapOrder[] calldata swapOrders) external;

    /// @notice Performs a swap via the swapModule module.
    /// @param order The swap order parameters.
    function swap(ISwapModule.SwapOrder calldata order) external;

    /// @notice Initiates a token transfer to the hub machine.
    /// @param token The address of the token to transfer.
    /// @param amount The amount of tokens to transfer.
    /// @param data ABI-encoded parameters required for bridge-related transfers. Ignored when called from a hub caliber.
    function transferToHubMachine(address token, uint256 amount, bytes calldata data) external;

    /// @notice Instructs the Caliber to pull the specified token amount from the calling hub machine endpoint.
    /// @param token The address of the token being transferred.
    /// @param amount The amount of tokens being transferred.
    function notifyIncomingTransfer(address token, uint256 amount) external;

    /// @notice Sets the position accounting staleness threshold.
    /// @param newPositionStaleThreshold The new threshold in seconds.
    function setPositionStaleThreshold(uint256 newPositionStaleThreshold) external;

    /// @notice Sets the duration of the allowedInstrRoot update timelock.
    /// @param newTimelockDuration The new duration in seconds.
    function setTimelockDuration(uint256 newTimelockDuration) external;

    /// @notice Schedules an update of the root of the Merkle tree containing allowed instructions.
    /// @dev The update will take effect after the timelock duration stored in the contract
    /// at the time of the call.
    /// @param newMerkleRoot The new Merkle root.
    function scheduleAllowedInstrRootUpdate(bytes32 newMerkleRoot) external;

    /// @notice Cancels a scheduled update of the root of the Merkle tree containing allowed instructions.
    /// @dev Reverts if no pending update exists or if the timelock has expired.
    function cancelAllowedInstrRootUpdate() external;

    /// @notice Sets the max allowed value loss for position increases.
    /// @param newMaxPositionIncreaseLossBps The new max value loss in basis points.
    function setMaxPositionIncreaseLossBps(uint256 newMaxPositionIncreaseLossBps) external;

    /// @notice Sets the max allowed value loss for position decreases.
    /// @param newMaxPositionDecreaseLossBps The new max value loss in basis points.
    function setMaxPositionDecreaseLossBps(uint256 newMaxPositionDecreaseLossBps) external;

    /// @notice Sets the max allowed value loss for base token swaps.
    /// @param newMaxSwapLossBps The new max value loss in basis points.
    function setMaxSwapLossBps(uint256 newMaxSwapLossBps) external;

    /// @notice Sets the duration of the cooldown period for swaps and position management.
    /// @param newCooldownDuration The new duration in seconds.
    function setCooldownDuration(uint256 newCooldownDuration) external;

    /// @notice Adds a new guardian for the Merkle tree containing allowed instructions.
    /// @param newGuardian The address of the new guardian.
    function addInstrRootGuardian(address newGuardian) external;

    /// @notice Removes a guardian for the Merkle tree containing allowed instructions.
    /// @param guardian The address of the guardian to remove.
    function removeInstrRootGuardian(address guardian) external;
}
