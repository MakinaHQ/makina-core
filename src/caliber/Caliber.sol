// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {VM} from "./vm/VM.sol";
import {IBaseMakinaRegistry} from "../interfaces/IBaseMakinaRegistry.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox} from "../interfaces/ICaliberMailbox.sol";
import {IMailbox} from "../interfaces/IMailbox.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";

contract Caliber is VM, AccessManagedUpgradeable, ICaliber {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20Metadata;

    /// @dev Full scale value in basis points
    uint256 private constant MAX_BPS = 10_000;

    /// @inheritdoc ICaliber
    address public immutable registry;

    /// @custom:storage-location erc7201:makina.storage.Caliber
    struct CaliberStorage {
        address _mailbox;
        address _accountingToken;
        address _mechanic;
        address _securityCouncil;
        uint256 _lastReportedAUM;
        uint256 _lastReportedAUMTime;
        uint256 _positionStaleThreshold;
        bytes32 _allowedInstrRoot;
        uint256 _timelockDuration;
        bytes32 _pendingAllowedInstrRoot;
        uint256 _pendingTimelockExpiry;
        uint256 _maxMgmtLossBps;
        uint256 _maxSwapLossBps;
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

    constructor(address _registry) {
        registry = _registry;
        _disableInitializers();
    }

    /// @inheritdoc ICaliber
    function initialize(InitParams calldata params) public override initializer {
        CaliberStorage storage $ = _getCaliberStorage();
        $._mailbox = _deployMailbox(params.mailboxBeacon, params.hubMachineEndpoint);
        $._accountingToken = params.accountingToken;
        $._positionStaleThreshold = params.initialPositionStaleThreshold;
        $._allowedInstrRoot = params.initialAllowedInstrRoot;
        $._timelockDuration = params.initialTimelockDuration;
        $._maxMgmtLossBps = params.initialMaxMgmtLossBps;
        $._maxSwapLossBps = params.initialMaxSwapLossBps;
        $._mechanic = params.initialMechanic;
        $._securityCouncil = params.initialSecurityCouncil;
        _addBaseToken(params.accountingToken, params.accountingTokenPosId);
        __AccessManaged_init(params.initialAuthority);
    }

    modifier onlyOperator() {
        CaliberStorage storage $ = _getCaliberStorage();
        if (msg.sender != ($._recoveryMode ? $._securityCouncil : $._mechanic)) {
            revert UnauthorizedOperator();
        }
        _;
    }

    /// @inheritdoc ICaliber
    function mailbox() public view override returns (address) {
        return _getCaliberStorage()._mailbox;
    }

    /// @inheritdoc ICaliber
    function accountingToken() public view override returns (address) {
        return _getCaliberStorage()._accountingToken;
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
    function lastReportedAUM() public view override returns (uint256) {
        return _getCaliberStorage()._lastReportedAUM;
    }

    /// @inheritdoc ICaliber
    function lastReportedAUMTime() public view returns (uint256) {
        return _getCaliberStorage()._lastReportedAUMTime;
    }

    /// @inheritdoc ICaliber
    function positionStaleThreshold() public view override returns (uint256) {
        return _getCaliberStorage()._positionStaleThreshold;
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
    function maxMgmtLossBps() public view override returns (uint256) {
        return _getCaliberStorage()._maxMgmtLossBps;
    }

    /// @inheritdoc ICaliber
    function maxSwapLossBps() public view override returns (uint256) {
        return _getCaliberStorage()._maxSwapLossBps;
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
        } else {
            pos.value = _accountingValueOf(bt, btBal);
        }
        pos.lastAccountingTime = block.timestamp;

        return (pos.value, int256(pos.value) - int256(lastValue));
    }

    /// @inheritdoc ICaliber
    function accountForPosition(Instruction calldata instruction) public override returns (uint256, int256) {
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
    function accountForPositionBatch(Instruction[] calldata instructions) public override {
        uint256 len = instructions.length;
        for (uint256 i; i < len; i++) {
            accountForPosition(instructions[i]);
        }
    }

    /// @inheritdoc ICaliber
    function updateAndReportCaliberAUM(Instruction[] calldata instructions) external override {
        accountForPositionBatch(instructions);
        CaliberStorage storage $ = _getCaliberStorage();
        // ICaliberMailbox($._mailbox).withdrawPendingReceivedAmounts();

        uint256 currentTimestamp = block.timestamp;
        uint256 len = $._positionIds.length();
        uint256 aum;
        uint256 debt;
        for (uint256 i; i < len; i++) {
            uint256 posId = $._positionIds.at(i);
            Position memory pos = $._positionById[posId];
            if ($._positionIdToBaseToken[posId] != address(0)) {
                (uint256 value,) = accountForBaseToken(posId);
                aum += value;
            } else if (currentTimestamp - pos.lastAccountingTime > $._positionStaleThreshold) {
                revert PositionAccountingStale(posId);
            } else if (pos.isDebt) {
                debt += pos.value;
            } else {
                aum += pos.value;
            }
        }

        $._lastReportedAUM = aum > debt ? aum - debt : 0;
        $._lastReportedAUMTime = currentTimestamp;

        ICaliberMailbox($._mailbox).notifyAccountingSlim($._lastReportedAUM);
    }

    /// @inheritdoc ICaliber
    function managePosition(Instruction[] calldata instructions)
        public
        override
        onlyOperator
        returns (uint256, int256)
    {
        CaliberStorage storage $ = _getCaliberStorage();

        if (instructions.length != 2) {
            revert InvalidInstructionsLength();
        }
        Instruction calldata managingInstruction = instructions[0];
        Instruction calldata accountingInstruction = instructions[1];

        uint256 posId = managingInstruction.positionId;
        if (posId == 0) {
            revert ZeroPositionId();
        }
        if (posId != accountingInstruction.positionId || managingInstruction.isDebt != accountingInstruction.isDebt) {
            revert UnmatchingInstructions();
        }
        if (managingInstruction.instructionType != InstructionType.MANAGEMENT) {
            revert InvalidInstructionType();
        }
        if ($._positionIdToBaseToken[posId] != address(0)) {
            revert BaseTokenPosition();
        }

        _checkInstructionIsAllowed(managingInstruction);

        uint256 inputTokensValueBefore;
        if (!$._recoveryMode) {
            for (uint256 i; i < managingInstruction.affectedTokens.length; i++) {
                address _affectedToken = managingInstruction.affectedTokens[i];
                if ($._baseTokenToPositionId[_affectedToken] == 0) {
                    revert InvalidAffectedToken();
                }
                inputTokensValueBefore +=
                    _accountingValueOf(_affectedToken, IERC20Metadata(_affectedToken).balanceOf(address(this)));
            }
        }

        _execute(managingInstruction.commands, managingInstruction.state);

        (uint256 value, int256 change) = _accountForPosition(accountingInstruction);

        if (change >= 0) {
            if ($._recoveryMode) {
                revert RecoveryMode();
            }
            uint256 inputTokensValueAfter;
            for (uint256 i; i < managingInstruction.affectedTokens.length; i++) {
                address _affectedToken = managingInstruction.affectedTokens[i];
                inputTokensValueAfter +=
                    _accountingValueOf(_affectedToken, IERC20Metadata(_affectedToken).balanceOf(address(this)));
            }
            int256 inputTokensValueChange = int256(inputTokensValueBefore) - int256(inputTokensValueAfter);
            if (
                inputTokensValueChange > 0
                    && uint256(change) < uint256(inputTokensValueChange).mulDiv(MAX_BPS - $._maxMgmtLossBps, MAX_BPS)
            ) {
                revert MaxValueLossExceeded();
            }
        }

        return (value, change);
    }

    /// @inheritdoc ICaliber
    function harvest(Instruction calldata instruction, ISwapper.SwapOrder[] calldata swapOrders)
        public
        override
        onlyOperator
    {
        if (instruction.instructionType != InstructionType.HARVEST) {
            revert InvalidInstructionType();
        }
        _checkInstructionIsAllowed(instruction);
        _execute(instruction.commands, instruction.state);
        for (uint256 i; i < swapOrders.length; i++) {
            swap(swapOrders[i]);
        }
    }

    /// @inheritdoc ICaliber
    function swap(ISwapper.SwapOrder calldata order) public override onlyOperator {
        CaliberStorage storage $ = _getCaliberStorage();
        if ($._recoveryMode && order.outputToken != $._accountingToken) {
            revert RecoveryMode();
        } else if ($._baseTokenToPositionId[order.outputToken] == 0) {
            revert InvalidOutputToken();
        }

        uint256 valBefore;
        bool isInputBaseToken = $._baseTokenToPositionId[order.inputToken] != 0;
        if (isInputBaseToken) {
            valBefore = _accountingValueOf(order.inputToken, order.inputAmount);
        }

        address _swapper = IBaseMakinaRegistry(registry).swapper();
        IERC20Metadata(order.inputToken).forceApprove(_swapper, order.inputAmount);
        uint256 amountOut = ISwapper(_swapper).swap(order);
        IERC20Metadata(order.inputToken).forceApprove(_swapper, 0);

        if (isInputBaseToken) {
            uint256 valAfter = _accountingValueOf(order.outputToken, amountOut);
            if (valAfter < valBefore.mulDiv(MAX_BPS - $._maxSwapLossBps, MAX_BPS)) {
                revert MaxValueLossExceeded();
            }
        }
    }

    /// @inheritdoc ICaliber
    function transferToHubMachine(address token, uint256 amount) public override onlyOperator {
        CaliberStorage storage $ = _getCaliberStorage();
        emit TransferToHubMachine(token, amount);
        IERC20Metadata(token).forceApprove($._mailbox, amount);
        ICaliberMailbox($._mailbox).manageTransferFromCaliberToMachine(token, amount);
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
    function setPositionStaleThreshold(uint256 newPositionStaleThreshold) public override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        emit PositionStaleThresholdChanged($._positionStaleThreshold, newPositionStaleThreshold);
        $._positionStaleThreshold = newPositionStaleThreshold;
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

    /// @inheritdoc ICaliber
    function setMaxMgmtLossBps(uint256 newMaxMgmtLossBps) external override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        emit MaxMgmtLossBpsChanged($._maxMgmtLossBps, newMaxMgmtLossBps);
        $._maxMgmtLossBps = newMaxMgmtLossBps;
    }

    /// @inheritdoc ICaliber
    function setMaxSwapLossBps(uint256 newMaxSwapLossBps) external override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        emit MaxSwapLossBpsChanged($._maxSwapLossBps, newMaxSwapLossBps);
        $._maxSwapLossBps = newMaxSwapLossBps;
    }

    /// @inheritdoc ICaliber
    function setRecoveryMode(bool enabled) public override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        if ($._recoveryMode != enabled) {
            $._recoveryMode = enabled;
            emit RecoveryModeChanged(enabled);
        }
    }

    /// @dev Deploys the caliber mailbox.
    function _deployMailbox(address mailboxBeacon, address hubMachineEndpoint)
        internal
        onlyInitializing
        returns (address)
    {
        address _mailbox = address(
            new BeaconProxy(mailboxBeacon, abi.encodeCall(IMailbox.initialize, (hubMachineEndpoint, address(this))))
        );
        emit MailboxDeployed(_mailbox);
        return _mailbox;
    }

    /// @dev Adds a new base token to storage.
    function _addBaseToken(address token, uint256 posId) internal {
        CaliberStorage storage $ = _getCaliberStorage();

        if ($._baseTokenToPositionId[token] != 0) {
            revert BaseTokenAlreadyExists();
        }
        if (posId == 0) {
            revert ZeroPositionId();
        }
        if (!$._positionIds.add(posId)) {
            revert PositionAlreadyExists();
        }

        $._baseTokenToPositionId[token] = posId;
        $._positionIdToBaseToken[posId] = token;

        $._positionById[posId] = Position({lastAccountingTime: 0, value: 0, isBaseToken: true, isDebt: false});
        emit PositionCreated(posId);

        // Reverts if no price feed is registered for token in the oracle registry.
        IOracleRegistry(IBaseMakinaRegistry(registry).oracleRegistry()).getTokenFeedData(token);
    }

    /// @dev Computes the accounting value of a non-base-token position. Depending on last and current value, the
    /// position is then either created, closed or simply updated in storage.
    function _accountForPosition(Instruction calldata instruction) internal returns (uint256, int256) {
        if (instruction.instructionType != InstructionType.ACCOUNTING) {
            revert InvalidInstructionType();
        }
        _checkInstructionIsAllowed(instruction);

        uint256[] memory amounts;
        {
            bytes[] memory returnedState = _execute(instruction.commands, instruction.state);
            amounts = _decodeAccountingOutputState(returnedState);
        }

        CaliberStorage storage $ = _getCaliberStorage();

        uint256 posId = instruction.positionId;
        Position storage pos = $._positionById[posId];
        uint256 lastValue = pos.value;
        uint256 currentValue;

        uint256 len = instruction.affectedTokens.length;
        if (amounts.length != len) {
            revert InvalidAccounting();
        }
        for (uint256 i; i < len; i++) {
            address token = instruction.affectedTokens[i];
            if ($._baseTokenToPositionId[token] == 0) {
                revert InvalidAffectedToken();
            }
            uint256 assetValue = _accountingValueOf(token, amounts[i]);
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
                pos.isDebt = instruction.isDebt;
                $._positionIds.add(posId);
                emit PositionCreated(posId);
            }
        }

        return (currentValue, int256(currentValue) - int256(lastValue));
    }

    /// @dev Decodes the output state of an accounting instruction into an array of amounts.
    function _decodeAccountingOutputState(bytes[] memory state) internal pure returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](state.length);

        uint256 count;
        for (uint256 i; i < state.length; i++) {
            if (bytes32(state[i]) == ACCOUNTING_OUTPUT_STATE_END_OF_ARGS) {
                break;
            }
            amounts[i] = uint256(bytes32(state[i]));
            count++;
        }

        // Resize the array to the actual number of amounts.
        assembly {
            mstore(amounts, count)
        }

        return amounts;
    }

    /// @dev Computes the accounting value of a given token amount.
    function _accountingValueOf(address token, uint256 amount) internal view returns (uint256) {
        CaliberStorage storage $ = _getCaliberStorage();
        if (token == $._accountingToken) {
            return amount;
        }
        uint256 price =
            IOracleRegistry(IBaseMakinaRegistry(registry).oracleRegistry()).getPrice(token, $._accountingToken);
        return amount.mulDiv(price, (10 ** IERC20Metadata(token).decimals()));
    }

    /// @dev Checks if the instruction is allowed for a given position.
    /// @param instruction The instruction to check.
    function _checkInstructionIsAllowed(Instruction calldata instruction) internal {
        bytes32 commandsHash = keccak256(abi.encodePacked(instruction.commands));
        bytes32 stateHash = _getStateHash(instruction.state, instruction.stateBitmap);
        bytes32 affectedTokensHash = keccak256(abi.encodePacked(instruction.affectedTokens));
        if (
            !_verifyInstructionProof(
                instruction.merkleProof,
                commandsHash,
                stateHash,
                instruction.stateBitmap,
                instruction.positionId,
                instruction.isDebt,
                affectedTokensHash,
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
    /// @param affectedTokensHash The hash of the affected tokens.
    /// @param stateBitmap The bitmap of the state.
    /// @param posId The position ID.
    /// @param instructionType The type of the instruction.
    /// @return isValid True if the proof is valid, false otherwise.
    function _verifyInstructionProof(
        bytes32[] memory proof,
        bytes32 commandsHash,
        bytes32 stateHash,
        uint128 stateBitmap,
        uint256 posId,
        bool isDebt,
        bytes32 affectedTokensHash,
        InstructionType instructionType
    ) internal returns (bool) {
        // The state transition hash is the hash of the commands, state, bitmap, position ID, isDebt flag, affected tokens and instruction type.
        bytes32 stateTransitionHash = keccak256(
            abi.encode(commandsHash, stateHash, stateBitmap, posId, isDebt, affectedTokensHash, instructionType)
        );
        return MerkleProof.verify(proof, _updateAllowedInstrRoot(), keccak256(abi.encode(stateTransitionHash)));
    }

    /// @dev Utility method to get the hash of the state based on bitmap.
    /// This allows a weiroll script to have both fixed and variable parameters.
    /// @param state The state to hash.
    /// @param stateBitmap The bitmap of the state.
    /// @return hash The hash of the state.
    function _getStateHash(bytes[] memory state, uint128 stateBitmap) internal pure returns (bytes32) {
        if (stateBitmap == uint128(0)) {
            return bytes32(0);
        }

        uint8 i;
        bytes memory hashInput;

        // Iterate through the state and hash values corresponding to indices marked in the bitmap.
        for (i; i < state.length;) {
            // If the bit is set as 1, hash the state value.
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
    /// @return currentRoot The current allowed instructions root.
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
