// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

interface ICaliber {
    error InvalidInputLength();
    error InvalidInstructions();
    error NegativeTokenPrice();
    error NotBaseTokenPosition();
    error NotMechanic();
    error BaseTokenAlreadyExists();
    error PositionAlreadyExists();
    error BaseTokenPosition();
    error RecoveryMode();
    error ZeroPositionID();

    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event PositionCreated(uint256 indexed id);
    event PositionClosed(uint256 indexed id);

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
        uint128 bitMap;
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

    /// @notice Address of the oracle registry
    function oracleRegistry() external view returns (address);

    /// @notice Address of the accounting token
    function accountingToken() external view returns (address);

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
    /// @param positionId ID of the base token position
    /// @return change The change in the position value
    function accountForBaseToken(uint256 positionId) external returns (int256 change);

    /// @notice Set a new mechanic
    /// @param newMechanic Address of new mechanic
    function setMechanic(address newMechanic) external;

    /// @notice Updates the state of a position
    /// @dev Each time a position is managed, the caliber also performs accounting,
    /// and creates or closes it if needed.
    /// @param instructions Array containing a manage instruction and optionally
    /// and accounting instruction, both for the same position
    function managePosition(Instruction[] calldata instructions) external;
}
