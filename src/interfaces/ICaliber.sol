// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

interface ICaliber {
    error NotMechanic();
    error PositionAlreadyExists();
    error PositionIsBaseToken();
    error ZeroPositionID();

    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event PositionAdded(uint256 indexed id, bool indexed isBaseToken);

    struct Position {
        uint256 lastAccounted; // Last block number when the position was accounted
        uint256 value; // Value of the position expressed in accounting token
        bool isBaseToken; // Is the position a base token
    }

    /// @notice Address of the hub machine
    function hubMachine() external view returns (address);

    /// @notice Address of the mechanic
    function mechanic() external view returns (address);

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

    /// @notice Set a new mechanic
    /// @param newMechanic Address of new mechanic
    function setMechanic(address newMechanic) external;
}
