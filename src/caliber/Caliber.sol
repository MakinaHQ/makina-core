// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {VM} from "./vm/VM.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";

contract Caliber is VM, AccessManagedUpgradeable, ICaliber {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @inheritdoc ICaliber
    address public immutable oracleRegistry;

    /// @custom:storage-location erc7201:makina.storage.Caliber
    struct CaliberStorage {
        address _hubMachine;
        address _accountingToken;
        address _mechanic;
        address _securityCouncil;
        bytes32 _allowedInstrRoot;
        uint256 _timelockDuration;
        bytes32 _pendingAllowedInstrRoot;
        uint256 _pendingTimelockExpiry;
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

    constructor(address oracleRegistry_) {
        oracleRegistry = oracleRegistry_;
        _disableInitializers();
    }

    /// @inheritdoc ICaliber
    function initialize(
        address hubMachine_,
        address accountingToken_,
        uint256 acountingTokenPosID_,
        bytes32 initialAllowedInstrRoot_,
        uint256 initialTimelockDuration_,
        address initialMechanic_,
        address initialSecurityCouncil_,
        address initialAuthority_
    ) public initializer {
        CaliberStorage storage $ = _getCaliberStorage();
        $._hubMachine = hubMachine_;
        $._accountingToken = accountingToken_;
        $._allowedInstrRoot = initialAllowedInstrRoot_;
        $._timelockDuration = initialTimelockDuration_;
        $._mechanic = initialMechanic_;
        $._securityCouncil = initialSecurityCouncil_;
        _addBaseToken(accountingToken_, acountingTokenPosID_);
        __AccessManaged_init(initialAuthority_);
    }

    modifier onlyOperator() {
        CaliberStorage storage $ = _getCaliberStorage();
        if (msg.sender != ($._recoveryMode ? $._securityCouncil : $._mechanic)) {
            revert UnauthorizedOperator();
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
    function securityCouncil() public view override returns (address) {
        return _getCaliberStorage()._securityCouncil;
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
    function allowedInstrRoot() public view override returns (bytes32) {
        CaliberStorage storage $ = _getCaliberStorage();
        return ($._pendingTimelockExpiry == 0 || block.timestamp < $._pendingTimelockExpiry)
            ? $._allowedInstrRoot
            : $._pendingAllowedInstrRoot;
    }

    /// @inheritdoc ICaliber
    function timelockDuration() public view override returns (uint256) {
        return _getCaliberStorage()._timelockDuration;
    }

    /// @inheritdoc ICaliber
    function pendingAllowedInstrRoot() public view override returns (bytes32) {
        CaliberStorage storage $ = _getCaliberStorage();
        return ($._pendingTimelockExpiry == 0 || block.timestamp >= $._pendingTimelockExpiry)
            ? bytes32(0)
            : $._pendingAllowedInstrRoot;
    }

    /// @inheritdoc ICaliber
    function pendingTimelockExpiry() public view override returns (uint256) {
        CaliberStorage storage $ = _getCaliberStorage();
        return ($._pendingTimelockExpiry == 0 || block.timestamp >= $._pendingTimelockExpiry)
            ? 0
            : $._pendingTimelockExpiry;
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
    function accountForBaseToken(uint256 posId) public returns (uint256, int256) {
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

        return (pos.value, int256(pos.value) - int256(lastValue));
    }

    /// @inheritdoc ICaliber
    function accountForPosition(Instruction calldata instruction) external override returns (uint256, int256) {
        CaliberStorage storage $ = _getCaliberStorage();
        if (!$._positionIds.contains(instruction.positionId)) {
            revert PositionDoesNotExist();
        }
        if ($._positionIdToBaseToken[instruction.positionId] != address(0)) {
            revert BaseTokenPosition();
        }
        return _accountForPosition(instruction);
    }

    /// @inheritdoc ICaliber
    function managePosition(Instruction[] calldata instructions) public override onlyOperator {
        CaliberStorage storage $ = _getCaliberStorage();

        if (instructions.length != 2) {
            revert InvalidInstructionsLength();
        }
        Instruction calldata managingInstruction = instructions[0];
        Instruction calldata accountingInstruction = instructions[1];

        uint256 posId = managingInstruction.positionId;
        if (posId != accountingInstruction.positionId) {
            revert UnmatchingInstructions();
        }
        if (managingInstruction.instructionType != InstructionType.MANAGE) {
            revert InvalidInstructionType();
        }
        if ($._positionIdToBaseToken[posId] != address(0)) {
            revert BaseTokenPosition();
        }

        _checkInstructionIsAllowed(managingInstruction);
        _execute(managingInstruction.commands, managingInstruction.state);
        (, int256 change) = _accountForPosition(accountingInstruction);

        if ($._recoveryMode && change >= 0) {
            revert RecoveryMode();
        }
    }

    /// @inheritdoc ICaliber
    function setMechanic(address newMechanic) public override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        emit MechanicChanged($._mechanic, newMechanic);
        $._mechanic = newMechanic;
    }

    /// @inheritdoc ICaliber
    function setSecurityCouncil(address newSecurityCouncil) public override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        emit SecurityCouncilChanged($._securityCouncil, newSecurityCouncil);
        $._securityCouncil = newSecurityCouncil;
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
    function setTimelockDuration(uint256 newTimelockDuration) external override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        emit TimelockDurationChanged($._timelockDuration, newTimelockDuration);
        $._timelockDuration = newTimelockDuration;
    }

    /// @inheritdoc ICaliber
    function scheduleAllowedInstrRootUpdate(bytes32 newMerkleRoot) external override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        _updateAllowedInstrRoot();
        if ($._pendingTimelockExpiry != 0) {
            revert ActiveUpdatePending();
        }
        $._pendingAllowedInstrRoot = newMerkleRoot;
        $._pendingTimelockExpiry = block.timestamp + $._timelockDuration;
        emit NewAllowedInstrRootScheduled(newMerkleRoot, $._pendingTimelockExpiry);
    }

    /// @dev Adds a new base token to storage.
    function _addBaseToken(address token, uint256 posId) internal {
        CaliberStorage storage $ = _getCaliberStorage();

        if ($._baseTokenToPositionId[token] != 0) {
            revert BaseTokenAlreadyExists();
        }

        // reverts if no price feed is registered for token in the oracle registry
        IOracleRegistry(oracleRegistry).getTokenFeedData(token);

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

    /// @dev Computes the accounting value of a non-base-token position
    /// Depending on last and current value, the position is then either created, closed or simply updated in storage.
    function _accountForPosition(Instruction calldata instruction) internal returns (uint256, int256) {
        if (instruction.instructionType != InstructionType.ACCOUNTING) {
            revert InvalidInstructionType();
        }
        _checkInstructionIsAllowed(instruction);
        bytes[] memory returnedState = _execute(instruction.commands, instruction.state);
        (address[] memory assets, uint256[] memory amounts) = _decodeAccountingOutputState(returnedState);

        uint256 posId = instruction.positionId;

        CaliberStorage storage $ = _getCaliberStorage();

        Position storage pos = $._positionById[posId];
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

        return (currentValue, int256(currentValue) - int256(lastValue));
    }

    /// @dev Decodes the output state of an accounting instruction into asset and amount arrays of equal length.
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
            if (i % 2 == 0 && i + 1 == state.length) {
                // last state entry is neither end-of-args flag nor an amount
                revert InvalidAccounting();
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

    /// @dev Computes the accounting value of a given token amount.
    function _accountingValueOf(address token, uint256 amount) internal view returns (uint256) {
        CaliberStorage storage $ = _getCaliberStorage();
        uint256 price = IOracleRegistry(oracleRegistry).getPrice(token, $._accountingToken);
        return amount.mulDiv(price, (10 ** IERC20Metadata(token).decimals()));
    }

    /// @dev Checks if the instruction is allowed for a given position.
    /// @param instruction The instruction to check.
    function _checkInstructionIsAllowed(Instruction calldata instruction) internal {
        // all commands are concatenated and hashed
        bytes32 commandsHash = keccak256(abi.encodePacked(instruction.commands));

        // states are hashed based on the bitmap
        bytes32 stateHash = _getStateHash(instruction.state, instruction.stateBitmap);

        if (
            !_verifyInstructionProof(
                instruction.merkleProof,
                commandsHash,
                stateHash,
                instruction.stateBitmap,
                instruction.positionId,
                instruction.instructionType
            )
        ) {
            revert InvalidInstructionProof();
        }
    }

    /// @dev Checks if a given proof is valid for a given instruction.
    /// @param proof The proof to check.
    /// @param commandsHash The hash of the commands.
    /// @param stateHash The hash of the state.
    /// @param stateBitmap The bitmap of the state.
    /// @param posId The position ID.
    /// @param instructionType The type of the instruction.
    /// @return boolean True if the proof is valid, false otherwise.
    function _verifyInstructionProof(
        bytes32[] memory proof,
        bytes32 commandsHash,
        bytes32 stateHash,
        uint128 stateBitmap,
        uint256 posId,
        InstructionType instructionType
    ) internal returns (bool) {
        // the state transition hash is the hash of the commands, state, bitmap, position ID and instruction type
        bytes32 stateTransitionHash =
            keccak256(abi.encode(commandsHash, stateHash, stateBitmap, posId, instructionType));
        return MerkleProof.verify(proof, _updateAllowedInstrRoot(), keccak256(abi.encode(stateTransitionHash)));
    }

    /// @dev Utility method to get the hash of the state based on bitmap.
    /// This allows a weiroll script to have both fixed and variable parameters.
    /// @param state The state to hash.
    /// @param stateBitmap The bitmap of the state.
    /// @return hash of the state.
    function _getStateHash(bytes[] memory state, uint128 stateBitmap) internal pure returns (bytes32) {
        if (stateBitmap == uint128(0)) {
            return bytes32(0);
        }

        uint8 i;
        bytes memory hashInput;

        // loop through the state and hash the values based on the bitmap
        // the bitmap encodes the index of the state that should be hashed
        for (i; i < state.length;) {
            // if the bit is set as 1, hash the state
            if (stateBitmap & (0x80000000000000000000000000000000 >> i) != 0) {
                hashInput = bytes.concat(hashInput, state[i]);
            }

            unchecked {
                ++i;
            }
        }
        return keccak256(hashInput);
    }

    /// @dev Updates the allowed instructions root if a pending update is scheduled and the timelock has expired.
    function _updateAllowedInstrRoot() internal returns (bytes32) {
        CaliberStorage storage $ = _getCaliberStorage();
        if ($._pendingTimelockExpiry != 0 && block.timestamp >= $._pendingTimelockExpiry) {
            $._allowedInstrRoot = $._pendingAllowedInstrRoot;
            delete $._pendingAllowedInstrRoot;
            delete $._pendingTimelockExpiry;
        }
        return $._allowedInstrRoot;
    }
}
