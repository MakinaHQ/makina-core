// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {ICaliberInbox} from "../interfaces/ICaliberInbox.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";

interface ICaliber {
    error BaseTokenPosition();
    error InvalidAccounting();
    error InvalidAffectedToken();
    error InvalidInputLength();
    error InvalidInstructionsLength();
    error InvalidInstructionProof();
    error InvalidInstructionType();
    error InvalidOutputToken();
    error UnmatchingInstructions();
    error MaxValueLossExceeded();
    error NegativeTokenPrice();
    error NotBaseTokenPosition();
    error BaseTokenAlreadyExists();
    error PositionAccountingStale(uint256 posId);
    error PositionAlreadyExists();
    error PositionDoesNotExist();
    error RecoveryMode();
    error TimelockDurationTooShort();
    error UnauthorizedOperator();
    error ActiveUpdatePending();
    error ZeroPositionID();

    event InboxDeployed(address indexed inbox);
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event SecurityCouncilChanged(address indexed oldSecurityCouncil, address indexed newecurityCouncil);
    event PositionStaleThresholdChanged(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    event RecoveryModeChanged(bool indexed enabled);
    event PositionCreated(uint256 indexed id);
    event PositionClosed(uint256 indexed id);
    event NewAllowedInstrRootScheduled(bytes32 indexed newMerkleRoot, uint256 indexed effectiveTime);
    event TimelockDurationChanged(uint256 indexed oldDuration, uint256 indexed newDuration);
    event MaxMgmtLossBpsChanged(uint256 indexed oldMaxMgmtLossBps, uint256 indexed newMaxMgmtLossBps);
    event MaxSwapLossBpsChanged(uint256 indexed oldMaxSwapLossBps, uint256 indexed newMaxSwapLossBps);

    enum InstructionType {
        MANAGE,
        ACCOUNTING,
        HARVEST
    }

    /// @notice Initialization parameters
    /// @param hubMachineInbox Address of the hub machine inbox
    /// @param accountingToken Address of the accounting token
    /// @param acountingTokenPosID ID for the accounting token position
    /// @param initialPositionStaleThreshold Position accounting staleness threshold in seconds
    /// @param initialAllowedInstrRoot Root of the Merkle tree containing allowed instructions
    /// @param initialTimelockDuration Duration of the allowedInstrRoot update timelock
    /// @param initialMaxMgmtLossBps Max allowed value loss (in basis point) for position management
    /// @param initialMaxSwapLossBps Max allowed value loss (in basis point) for base token swaps
    /// @param initialMechanic Address of the initial mechanic
    /// @param initialSecurityCouncil Address of the initial security council
    /// @param initialAuthority Address of the initial authority
    struct InitParams {
        address hubMachineInbox;
        address accountingToken;
        uint256 acountingTokenPosID;
        uint256 initialPositionStaleThreshold;
        bytes32 initialAllowedInstrRoot;
        uint256 initialTimelockDuration;
        uint256 initialMaxMgmtLossBps;
        uint256 initialMaxSwapLossBps;
        address initialMechanic;
        address initialSecurityCouncil;
        address initialAuthority;
    }

    struct Instruction {
        uint256 positionId; // required for ManagePosition, can be 0x0
        InstructionType instructionType;
        address[] affectedTokens;
        bytes32[] commands;
        bytes[] state;
        uint128 stateBitmap;
        bytes32[] merkleProof;
    }

    struct Position {
        uint256 lastAccountingTime; // Last block timestamp when the position was accounted for
        uint256 value; // Value of the position expressed in accounting token
        bool isBaseToken; // Is the position a base token
    }

    /// @notice Initializer of the contract
    /// @param params Initialization parameters
    function initialize(InitParams calldata params) external;

    /// @notice Address of the Makina registry
    function registry() external view returns (address);

    /// @notice Address of the inbox
    function inbox() external view returns (address);

    /// @notice Address of the mechanic
    function mechanic() external view returns (address);

    /// @notice Address of the security council
    function securityCouncil() external view returns (address);

    /// @notice Address of the accounting token
    function accountingToken() external view returns (address);

    /// @notice Caliber's AUM (expressed in accounting token) as of the last report to the hub machine
    function lastReportedAUM() external view returns (uint256);

    /// @notice Timestamp of the last caliber's AUM report to the hub machine
    function lastReportedAUMTime() external view returns (uint256);

    /// @notice Maximum duration a position can remain unaccounted for before it is considered stale
    function positionStaleThreshold() external view returns (uint256);

    /// @notice Is the caliber in recovery mode
    function recoveryMode() external view returns (bool);

    /// @notice Root of the Merkle tree containing allowed instructions
    function allowedInstrRoot() external view returns (bytes32);

    /// @notice Duration of the allowedInstrRoot update timelock
    function timelockDuration() external view returns (uint256);

    /// @notice Value of the pending allowedInstrRoot, if any
    function pendingAllowedInstrRoot() external view returns (bytes32);

    /// @notice Effective time of the last scheduled allowedInstrRoot update
    function pendingTimelockExpiry() external view returns (uint256);

    /// @notice Max allowed value loss (in basis point) for position management
    function maxMgmtLossBps() external view returns (uint256);

    /// @notice Max allowed value loss (in basis point) for base token swaps
    function maxSwapLossBps() external view returns (uint256);

    /// @notice Length of the position IDs array
    function getPositionsLength() external view returns (uint256);

    /// @dev Position index => position ID
    function getPositionId(uint256 idx) external view returns (uint256);

    /// @dev Position ID => position data
    function getPosition(uint256 id) external view returns (Position memory);

    /// @dev Token => is a base token in this caliber
    function isBaseToken(address token) external view returns (bool);

    /// @notice Add a new base token
    /// @param token Address of the base token
    /// @param positionId ID for the base token position
    function addBaseToken(address token, uint256 positionId) external;

    /// @dev Account for a base token position
    /// @param posId ID of the base token position
    /// @return value The new position value
    /// @return change The change in the position value
    function accountForBaseToken(uint256 posId) external returns (uint256 value, int256 change);

    /// @notice Account for a position
    /// @dev If the position value goes to zero, it is closed
    /// @param instruction Accounting instruction
    /// @return value The new position value
    /// @return change The change in the position value
    function accountForPosition(Instruction calldata instruction) external returns (uint256 value, int256 change);

    /// @notice Account for a batch of positions
    /// @dev If a position value goes to zero, it is closed
    /// @param instructions Array of accounting instructions
    function accountForPositionBatch(Instruction[] calldata instructions) external;

    /// @notice Update and report the caliber's AUM to the hub machine
    /// @param instructions Array of accounting instructions to be performed before the AUM computation
    /// @return accountingMessage Accounting message to be sent to the hub machine
    function updateAndReportCaliberAUM(Instruction[] calldata instructions)
        external
        returns (ICaliberInbox.AccountingMessageSlim memory accountingMessage);

    /// @notice Updates the state of a position
    /// @dev Each time a position is managed, the caliber also performs accounting,
    /// and creates or closes it if needed.
    /// @param instructions Array containing a manage instruction and optionally
    /// and accounting instruction, both for the same position
    /// @return value The new position value
    /// @return change The change in the position value
    function managePosition(Instruction[] calldata instructions) external returns (uint256 value, int256 change);

    /// @notice Perform a swap via the swapper module
    /// @param order Swap order parameters
    function swap(ISwapper.SwapOrder calldata order) external;

    /// @notice Set a new mechanic
    /// @param newMechanic Address of new mechanic
    function setMechanic(address newMechanic) external;

    /// @notice Set a new security council
    /// @param newSecurityCouncil Address of the new security council
    function setSecurityCouncil(address newSecurityCouncil) external;

    /// @notice Set the position accounting staleness threshold
    /// @param newPositionStaleThreshold New threshold in seconds
    function setPositionStaleThreshold(uint256 newPositionStaleThreshold) external;

    /// @notice Set the recovery mode
    /// @param enabled True to enable recovery mode, false to disable
    function setRecoveryMode(bool enabled) external;

    /// @notice Set the duration of the allowedInstrRoot update timelock
    /// @param newTimelockDuration New duration in seconds
    function setTimelockDuration(uint256 newTimelockDuration) external;

    /// @notice Schedule an update of the root of the Merkle tree containing allowed instructions
    /// @dev The update will take effect after the timelock duration stored in the contract
    /// at the time of the call.
    /// @param newMerkleRoot Root of the Merkle tree containing allowed instructions
    function scheduleAllowedInstrRootUpdate(bytes32 newMerkleRoot) external;

    /// @notice Set the max allowed value loss for position management
    /// @param newMaxMgmtLossBps New max value loss in basis points
    function setMaxMgmtLossBps(uint256 newMaxMgmtLossBps) external;

    /// @notice Set the max allowed value loss for base token swaps
    /// @param newMaxSwapLossBps New max value loss in basis points
    function setMaxSwapLossBps(uint256 newMaxSwapLossBps) external;
}
