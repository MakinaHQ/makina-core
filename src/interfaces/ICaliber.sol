// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

interface ICaliber {
    error InvalidAccounting();
    error InvalidInputLength();
    error InvalidInstructionsLength();
    error InvalidInstructionProof();
    error InvalidInstructionType();
    error UnmatchingInstructions();
    error NegativeTokenPrice();
    error NotBaseTokenPosition();
    error BaseTokenAlreadyExists();
    error PositionAlreadyExists();
    error PositionDoesNotExist();
    error BaseTokenPosition();
    error RecoveryMode();
    error TimelockDurationTooShort();
    error UnauthorizedOperator();
    error ActiveUpdatePending();
    error ZeroPositionID();

    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event SecurityCouncilChanged(address indexed oldSecurityCouncil, address indexed newecurityCouncil);
    event RecoveryModeChanged(bool indexed enabled);
    event PositionCreated(uint256 indexed id);
    event PositionClosed(uint256 indexed id);
    event NewAllowedInstrRootScheduled(bytes32 indexed newMerkleRoot, uint256 indexed effectiveTime);
    event TimelockDurationChanged(uint256 indexed oldDuration, uint256 indexed newDuration);

    enum InstructionType {
        MANAGE,
        ACCOUNTING,
        HARVEST
    }

    struct Instruction {
        uint256 positionId; // required for ManagePosition, can be 0x0
        InstructionType instructionType;
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

    /// @notice Address of the hub machine
    function hubMachine() external view returns (address);

    /// @notice Address of the mechanic
    function mechanic() external view returns (address);

    /// @notice Address of the security council
    function securityCouncil() external view returns (address);

    /// @notice Address of the oracle registry
    function oracleRegistry() external view returns (address);

    /// @notice Address of the accounting token
    function accountingToken() external view returns (address);

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

    /// @notice Set a position as a base token
    function setPositionAsBaseToken(uint256 posId, address token) external;

    /// @notice Set a position as a non-base token
    function setPositionAsNonBaseToken(uint256 posId) external;

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

    /// @notice Updates the state of a position
    /// @dev Each time a position is managed, the caliber also performs accounting,
    /// and creates or closes it if needed.
    /// @param instructions Array containing a manage instruction and optionally
    /// and accounting instruction, both for the same position
    function managePosition(Instruction[] calldata instructions) external;

    /// @notice Set a new mechanic
    /// @param newMechanic Address of new mechanic
    function setMechanic(address newMechanic) external;

    /// @notice Set a new security council
    /// @param newSecurityCouncil Address of the new security council
    function setSecurityCouncil(address newSecurityCouncil) external;

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
}
