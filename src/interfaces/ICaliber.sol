// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {ICaliberInbox} from "../interfaces/ICaliberInbox.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";

interface ICaliber {
    error ActiveUpdatePending();
    error BaseTokenAlreadyExists();
    error BaseTokenPosition();
    error InvalidAccounting();
    error InvalidAffectedToken();
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

    event InboxDeployed(address indexed inbox);
    event MaxMgmtLossBpsChanged(uint256 indexed oldMaxMgmtLossBps, uint256 indexed newMaxMgmtLossBps);
    event MaxSwapLossBpsChanged(uint256 indexed oldMaxSwapLossBps, uint256 indexed newMaxSwapLossBps);
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event NewAllowedInstrRootScheduled(bytes32 indexed newMerkleRoot, uint256 indexed effectiveTime);
    event PositionClosed(uint256 indexed id);
    event PositionCreated(uint256 indexed id);
    event PositionStaleThresholdChanged(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    event RecoveryModeChanged(bool indexed enabled);
    event SecurityCouncilChanged(address indexed oldSecurityCouncil, address indexed newecurityCouncil);
    event TimelockDurationChanged(uint256 indexed oldDuration, uint256 indexed newDuration);

    enum InstructionType {
        MANAGE,
        ACCOUNTING,
        HARVEST
    }

    /// @notice Initialization parameters.
    /// @param hubMachineInbox The address of the hub machine inbox.
    /// @param accountingToken The address of the accounting token.
    /// @param accountingTokenPosId The ID of the accounting token position.
    /// @param initialPositionStaleThreshold The position accounting staleness threshold in seconds.
    /// @param initialAllowedInstrRoot The root of the Merkle tree containing allowed instructions.
    /// @param initialTimelockDuration The duration of the allowedInstrRoot update timelock.
    /// @param initialMaxMgmtLossBps The max allowed value loss (in basis point) for position management.
    /// @param initialMaxSwapLossBps The max allowed value loss (in basis point) for base token swaps.
    /// @param initialMechanic The address of the initial mechanic.
    /// @param initialSecurityCouncil The address of the initial security council.
    /// @param initialAuthority The address of the initial authority.
    struct InitParams {
        address hubMachineInbox;
        address accountingToken;
        uint256 accountingTokenPosId;
        uint256 initialPositionStaleThreshold;
        bytes32 initialAllowedInstrRoot;
        uint256 initialTimelockDuration;
        uint256 initialMaxMgmtLossBps;
        uint256 initialMaxSwapLossBps;
        address initialMechanic;
        address initialSecurityCouncil;
        address initialAuthority;
    }

    /// @notice Instruction parameters.
    /// @param positionId The ID of the position concerned.
    /// @param instructionType The type of the instruction.
    /// @param affectedTokens The array of affected tokens.
    /// @param commands The array of commands.
    /// @param state The array of state.
    /// @param stateBitmap The state bitmap.
    /// @param merkleProof The array of Merkle proof elements.
    struct Instruction {
        uint256 positionId;
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
    struct Position {
        uint256 lastAccountingTime;
        uint256 value;
        bool isBaseToken;
    }

    /// @notice Initializer of the contract.
    /// @param params The initialization parameters.
    function initialize(InitParams calldata params) external;

    /// @notice Address of the Makina registry.
    function registry() external view returns (address);

    /// @notice Address of the inbox.
    function inbox() external view returns (address);

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

    /// @notice Max allowed value loss (in basis point) for position management.
    function maxMgmtLossBps() external view returns (uint256);

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
    /// @dev If a position value goes to zero, it is closed.
    /// @param instructions The array of accounting instructions.
    function accountForPositionBatch(Instruction[] calldata instructions) external;

    /// @notice Updates and reports the caliber's AUM to the hub machine.
    /// @param instructions The array of accounting instructions to be performed before the AUM computation.
    /// @return accountingMessage The accounting message to be sent to the hub machine.
    function updateAndReportCaliberAUM(Instruction[] calldata instructions)
        external
        returns (ICaliberInbox.AccountingMessageSlim memory accountingMessage);

    /// @notice Updates the state of a position.
    /// @dev Each time a position is managed, the caliber also performs accounting,
    /// and creates or closes it if needed.
    /// @param instructions The array containing a manage instruction and optionally
    /// and accounting instruction, both for the same position.
    /// @return value The new position value.
    /// @return change The change in the position value.
    function managePosition(Instruction[] calldata instructions) external returns (uint256 value, int256 change);

    /// @notice Performs a swap via the swapper module.
    /// @param order The swap order parameters.
    function swap(ISwapper.SwapOrder calldata order) external;

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

    /// @notice Sets the max allowed value loss for position management.
    /// @param newMaxMgmtLossBps The new max value loss in basis points.
    function setMaxMgmtLossBps(uint256 newMaxMgmtLossBps) external;

    /// @notice Sets the max allowed value loss for base token swaps.
    /// @param newMaxSwapLossBps The new max value loss in basis points.
    function setMaxSwapLossBps(uint256 newMaxSwapLossBps) external;
}
