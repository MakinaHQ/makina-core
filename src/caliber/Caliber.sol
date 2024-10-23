// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {VM} from "./vm/VM.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";

contract Caliber is VM, AccessManagedUpgradeable, ICaliber {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @custom:storage-location erc7201:makina.storage.Caliber
    struct CaliberStorage {
        address _hubMachine;
        address _accountingToken;
        address _oracleRegistry;
        address _mechanic;
        bool _recoveryMode;
        mapping(address bt => uint256 posId) _baseTokenToPositionId;
        mapping(uint256 posId => address bt) _positionIdToBaseToken;
        mapping(uint256 posId => Position pos) _positionById;
        EnumerableSet.UintSet _positionIds;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.Caliber")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CaliberStorageLocation = 0x32461bf02c7aa4aa351cd04411b6c7b9348073fbccf471c7b347bdaada044b00;

    bytes32 private constant ACCOUNTING_OUTPUT_STATE_END_OF_ARGS = bytes32(type(uint256).max);

    function _getCaliberStorage() private pure returns (CaliberStorage storage $) {
        assembly {
            $.slot := CaliberStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address hubMachine_,
        address accountingToken_,
        uint256 acountingTokenPosID_,
        address oracleRegistry_,
        address initialMechanic_,
        address initialAuthority_
    ) public initializer {
        CaliberStorage storage $ = _getCaliberStorage();
        $._hubMachine = hubMachine_;
        $._accountingToken = accountingToken_;
        $._oracleRegistry = oracleRegistry_;
        $._mechanic = initialMechanic_;
        _addBaseToken(accountingToken_, acountingTokenPosID_);
        __AccessManaged_init(initialAuthority_);
    }

    modifier onlyMechanic() {
        if (msg.sender != _getCaliberStorage()._mechanic) {
            revert NotMechanic();
        }
        _;
    }

    /// @inheritdoc ICaliber
    function hubMachine() public view override returns (address) {
        return _getCaliberStorage()._hubMachine;
    }

    /// @inheritdoc ICaliber
    function mechanic() public view override returns (address) {
        return _getCaliberStorage()._mechanic;
    }

    /// @inheritdoc ICaliber
    function oracleRegistry() public view override returns (address) {
        return _getCaliberStorage()._oracleRegistry;
    }

    /// @inheritdoc ICaliber
    function accountingToken() public view override returns (address) {
        return _getCaliberStorage()._accountingToken;
    }

    /// @inheritdoc ICaliber
    function recoveryMode() public view override returns (bool) {
        return _getCaliberStorage()._recoveryMode;
    }

    /// @inheritdoc ICaliber
    function getPositionsLength() public view override returns (uint256) {
        return _getCaliberStorage()._positionIds.length();
    }

    /// @inheritdoc ICaliber
    function getPositionId(uint256 idx) public view override returns (uint256) {
        return _getCaliberStorage()._positionIds.at(idx);
    }

    /// @inheritdoc ICaliber
    function getPosition(uint256 posId) public view override returns (Position memory) {
        return _getCaliberStorage()._positionById[posId];
    }

    /// @inheritdoc ICaliber
    function isBaseToken(address token) public view override returns (bool) {
        return _getCaliberStorage()._baseTokenToPositionId[token] != 0;
    }

    /// @inheritdoc ICaliber
    function addBaseToken(address token, uint256 positionId) public override restricted {
        _addBaseToken(token, positionId);
    }

    /// @inheritdoc ICaliber
    function accountForBaseToken(uint256 posId) public returns (int256) {
        CaliberStorage storage $ = _getCaliberStorage();
        Position storage pos = $._positionById[posId];
        if ($._positionIdToBaseToken[posId] == address(0)) {
            revert NotBaseTokenPosition();
        }
        uint256 lastValue = pos.value;
        address bt = $._positionIdToBaseToken[posId];
        uint256 btBal = IERC20Metadata(bt).balanceOf(address(this));
        if (btBal == 0) {
            pos.value = 0;
        } else if (bt == $._accountingToken) {
            pos.value = btBal;
        } else {
            pos.value = _accountingValueOf(bt, btBal);
        }
        pos.lastAccountingTime = block.timestamp;

        return int256(pos.value) - int256(lastValue);
    }

    /// @inheritdoc ICaliber
    function setMechanic(address newMechanic) public override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        address currentMechanic = $._mechanic;
        emit MechanicChanged(currentMechanic, newMechanic);
        $._mechanic = newMechanic;
    }

    /// @inheritdoc ICaliber
    function setRecoveryMode(bool enabled) public override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        if ($._recoveryMode != enabled) {
            $._recoveryMode = enabled;
            emit RecoveryModeChanged(enabled);
        }
    }

    /// @inheritdoc ICaliber
    function managePosition(Instruction[] calldata instructions) public override {
        CaliberStorage storage $ = _getCaliberStorage();

        if (instructions.length == 0) {
            revert InvalidInstructions();
        }
        Instruction calldata managingInstruction = instructions[0];
        if (managingInstruction.instructionType != InstructionType.MANAGE) {
            revert InvalidInstructions();
        }
        _execute(managingInstruction.commands, managingInstruction.state);

        int256 change;
        uint256 posId = managingInstruction.positionId;
        if ($._positionIdToBaseToken[posId] != address(0)) {
            if (instructions.length != 1) {
                revert InvalidInstructions();
            }
            change = accountForBaseToken(posId);
        } else {
            if (instructions.length != 2) {
                revert InvalidInstructions();
            }
            Instruction calldata accountingInstruction = instructions[1];
            if (
                accountingInstruction.instructionType != InstructionType.ACCOUNTING
                    || posId != accountingInstruction.positionId
            ) {
                revert InvalidInstructions();
            }
            bytes[] memory returnedState = _execute(accountingInstruction.commands, accountingInstruction.state);
            (address[] memory assets, uint256[] memory amounts) = _decodeAccountingOutputState(returnedState);
            change = _updatePosition(posId, assets, amounts);
        }

        // reverts if caller is not the mechanic, unless the change is a position decrease in recovery mode
        if (msg.sender != _getCaliberStorage()._mechanic && (!$._recoveryMode || change >= 0)) {
            revert NotMechanic();
        }
        // reverts if the change is positive and recovery mode is active
        if ($._recoveryMode && change >= 0) {
            revert RecoveryMode();
        }
    }

    /// @dev Adds a new base token to storage.
    function _addBaseToken(address token, uint256 posId) internal {
        CaliberStorage storage $ = _getCaliberStorage();

        // reverts if no price feed is registered for token in the oracle registry
        IOracleRegistry($._oracleRegistry).getTokenFeedData(token);

        $._baseTokenToPositionId[token] = posId;
        $._positionIdToBaseToken[posId] = token;

        Position memory pos = Position({lastAccountingTime: 0, value: 0, isBaseToken: true});
        _addPosition(pos, posId);
    }

    /// @dev Adds a new position to storage.
    function _addPosition(Position memory pos, uint256 posId) internal {
        if (posId == 0) {
            revert ZeroPositionID();
        }
        CaliberStorage storage $ = _getCaliberStorage();
        if ($._positionIds.contains(posId)) {
            revert PositionAlreadyExists();
        }
        $._positionIds.add(posId);
        $._positionById[posId] = pos;
        emit PositionCreated(posId);
    }

    /// @dev Computes the accounting value of a given token amount.
    function _accountingValueOf(address token, uint256 amount) internal view returns (uint256) {
        CaliberStorage storage $ = _getCaliberStorage();
        uint256 price = IOracleRegistry($._oracleRegistry).getPrice(token, $._accountingToken);
        return amount.mulDiv(price, (10 ** IERC20Metadata(token).decimals()));
    }

    /// @dev Decodes the output state of an accounting instruction.
    function _decodeAccountingOutputState(bytes[] memory state)
        internal
        pure
        returns (address[] memory, uint256[] memory)
    {
        uint256 maxEntries = state.length / 2;
        address[] memory assets = new address[](maxEntries);
        uint256[] memory amounts = new uint256[](maxEntries);

        uint256 count;
        for (uint256 i; i < state.length; i++) {
            if (bytes32(state[i]) == ACCOUNTING_OUTPUT_STATE_END_OF_ARGS) {
                if (i % 2 == 1) {
                    revert InvalidAccounting();
                }
                break;
            }
            if (i % 2 == 0) {
                assets[i / 2] = address(uint160(uint256(bytes32(state[i]))));
            } else {
                amounts[i / 2] = uint256(bytes32(state[i]));
                count++; // count the number of asset/amount pairs
            }
        }

        // Resize the arrays to the actual number of entries
        assembly {
            mstore(assets, count)
            mstore(amounts, count)
        }

        return (assets, amounts);
    }

    /// @dev Computes the accounting value of a non-base-token position, based on the provided
    /// assets and amounts, assumed to have equal length.
    /// The position can be either created, closed or simply updated.
    function _updatePosition(uint256 posId, address[] memory assets, uint256[] memory amounts)
        internal
        returns (int256)
    {
        CaliberStorage storage $ = _getCaliberStorage();
        Position storage pos = $._positionById[posId];

        if ($._positionIdToBaseToken[posId] != address(0)) {
            revert BaseTokenPosition();
        }

        uint256 lastValue = pos.value;
        uint256 currentValue;

        uint256 len = assets.length;
        for (uint256 i; i < len; i++) {
            if ($._baseTokenToPositionId[assets[i]] == 0) {
                revert InvalidAccounting();
            }
            uint256 assetValue = _accountingValueOf(assets[i], amounts[i]);
            currentValue += assetValue;
        }

        if (lastValue > 0 && currentValue == 0) {
            $._positionIds.remove(posId);
            delete $._positionById[posId];
            emit PositionClosed(posId);
        } else if (currentValue > 0) {
            pos.value = currentValue;
            pos.lastAccountingTime = block.timestamp;
            if (lastValue == 0) {
                $._positionIds.add(posId);
                emit PositionCreated(posId);
            }
        }

        return int256(currentValue) - int256(lastValue);
    }
}
