// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IWeirollVM} from "../interfaces/IWeirollVM.sol";
import {IBaseMakinaRegistry} from "../interfaces/IBaseMakinaRegistry.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox} from "../interfaces/ICaliberMailbox.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";

contract Caliber is AccessManagedUpgradeable, ICaliber {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20Metadata;

    /// @dev Full scale value in basis points
    uint256 private constant MAX_BPS = 10_000;

    /// @inheritdoc ICaliber
    address public immutable registry;

    /// @inheritdoc ICaliber
    address public immutable weirollVm;

    /// @custom:storage-location erc7201:makina.storage.Caliber
    struct CaliberStorage {
        address _mailbox;
        address _accountingToken;
        address _mechanic;
        address _securityCouncil;
        uint256 _positionStaleThreshold;
        bytes32 _allowedInstrRoot;
        uint256 _timelockDuration;
        bytes32 _pendingAllowedInstrRoot;
        uint256 _pendingTimelockExpiry;
        uint256 _maxPositionIncreaseLossBps;
        uint256 _maxPositionDecreaseLossBps;
        uint256 _maxSwapLossBps;
        bool _recoveryMode;
        mapping(uint256 posId => Position pos) _positionById;
        EnumerableSet.UintSet _positionIds;
        EnumerableSet.AddressSet _baseTokens;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.Caliber")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CaliberStorageLocation = 0x32461bf02c7aa4aa351cd04411b6c7b9348073fbccf471c7b347bdaada044b00;

    bytes32 private constant ACCOUNTING_OUTPUT_STATE_END_OF_ARGS = bytes32(type(uint256).max);

    function _getCaliberStorage() private pure returns (CaliberStorage storage $) {
        assembly {
            $.slot := CaliberStorageLocation
        }
    }

    constructor(address _registry, address _weirollVm) {
        registry = _registry;
        weirollVm = _weirollVm;
        _disableInitializers();
    }

    /// @inheritdoc ICaliber
    function initialize(CaliberInitParams calldata params, address mailboxBeacon) public override initializer {
        CaliberStorage storage $ = _getCaliberStorage();
        $._mailbox = _deployMailbox(mailboxBeacon, params.hubMachineEndpoint);
        $._accountingToken = params.accountingToken;
        $._positionStaleThreshold = params.initialPositionStaleThreshold;
        $._allowedInstrRoot = params.initialAllowedInstrRoot;
        $._timelockDuration = params.initialTimelockDuration;
        $._maxPositionIncreaseLossBps = params.initialMaxPositionIncreaseLossBps;
        $._maxPositionDecreaseLossBps = params.initialMaxPositionDecreaseLossBps;
        $._maxSwapLossBps = params.initialMaxSwapLossBps;
        $._mechanic = params.initialMechanic;
        $._securityCouncil = params.initialSecurityCouncil;
        _addBaseToken(params.accountingToken);
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
    function maxPositionIncreaseLossBps() public view override returns (uint256) {
        return _getCaliberStorage()._maxPositionIncreaseLossBps;
    }

    /// @inheritdoc ICaliber
    function maxPositionDecreaseLossBps() public view override returns (uint256) {
        return _getCaliberStorage()._maxPositionDecreaseLossBps;
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
        return _getCaliberStorage()._baseTokens.contains(token);
    }

    /// @inheritdoc ICaliber
    function getBaseTokensLength() public view override returns (uint256) {
        return _getCaliberStorage()._baseTokens.length();
    }

    /// @inheritdoc ICaliber
    function getBaseTokenAddress(uint256 idx) public view override returns (address) {
        return _getCaliberStorage()._baseTokens.at(idx);
    }

    /// @inheritdoc ICaliber
    function addBaseToken(address token) public override restricted {
        _addBaseToken(token);
    }

    /// @inheritdoc ICaliber
    function accountForPosition(Instruction calldata instruction) public override returns (uint256, int256) {
        CaliberStorage storage $ = _getCaliberStorage();
        if (!$._positionIds.contains(instruction.positionId)) {
            revert PositionDoesNotExist();
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
    function isAccountingFresh() external view returns (bool) {
        CaliberStorage storage $ = _getCaliberStorage();

        uint256 len = $._positionIds.length();
        uint256 currentTimestamp = block.timestamp;
        for (uint256 i; i < len; i++) {
            if (currentTimestamp - $._positionById[$._positionIds.at(i)].lastAccountingTime > $._positionStaleThreshold)
            {
                return false;
            }
        }

        return true;
    }

    /// @inheritdoc ICaliber
    function getDetailedAum() external view override returns (uint256, bytes[] memory, bytes[] memory) {
        CaliberStorage storage $ = _getCaliberStorage();

        uint256 currentTimestamp = block.timestamp;
        uint256 aum;
        uint256 debt;

        uint256 len = $._positionIds.length();
        bytes[] memory positionsValues = new bytes[](len);
        for (uint256 i; i < len; i++) {
            uint256 posId = $._positionIds.at(i);
            Position memory pos = $._positionById[posId];
            if (currentTimestamp - $._positionById[posId].lastAccountingTime > $._positionStaleThreshold) {
                revert PositionAccountingStale(posId);
            } else if (pos.isDebt) {
                debt += pos.value;
            } else {
                aum += pos.value;
            }
            positionsValues[i] = abi.encode(posId, pos.value, pos.isDebt);
        }

        len = $._baseTokens.length();
        bytes[] memory baseTokensValues = new bytes[](len);
        for (uint256 i; i < len; i++) {
            address bt = $._baseTokens.at(i);
            uint256 btBal = IERC20Metadata(bt).balanceOf(address(this));
            uint256 value = btBal == 0 ? 0 : _accountingValueOf(bt, btBal);
            aum += value;
            baseTokensValues[i] = abi.encode(bt, value);
        }

        uint256 netAum = aum > debt ? aum - debt : 0;

        return (netAum, positionsValues, baseTokensValues);
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

        _accountForPosition(accountingInstruction);

        _checkInstructionIsAllowed(managingInstruction);

        uint256 affectedTokensValueBefore;
        for (uint256 i; i < managingInstruction.affectedTokens.length; i++) {
            address _affectedToken = managingInstruction.affectedTokens[i];
            if (!$._baseTokens.contains(_affectedToken)) {
                revert InvalidAffectedToken();
            }
            affectedTokensValueBefore +=
                _accountingValueOf(_affectedToken, IERC20Metadata(_affectedToken).balanceOf(address(this)));
        }

        _execute(managingInstruction.commands, managingInstruction.state);

        (uint256 value, int256 change) = _accountForPosition(accountingInstruction);

        uint256 affectedTokensValueAfter;
        for (uint256 i; i < managingInstruction.affectedTokens.length; i++) {
            address _affectedToken = managingInstruction.affectedTokens[i];
            affectedTokensValueAfter +=
                _accountingValueOf(_affectedToken, IERC20Metadata(_affectedToken).balanceOf(address(this)));
        }

        bool isBaseTokenInflow = affectedTokensValueAfter >= affectedTokensValueBefore;
        bool isPositionIncrease = change >= 0;
        uint256 absChange = isPositionIncrease ? uint256(change) : uint256(-change);
        uint256 maxLossBps = isPositionIncrease ? $._maxPositionIncreaseLossBps : $._maxPositionDecreaseLossBps;

        if (isPositionIncrease && $._recoveryMode) {
            revert RecoveryMode();
        }

        if (isBaseTokenInflow) {
            if (managingInstruction.isDebt == isPositionIncrease) {
                _checkPositionMaxDelta(absChange, affectedTokensValueAfter - affectedTokensValueBefore, maxLossBps);
            }
        } else {
            if (managingInstruction.isDebt == isPositionIncrease) {
                revert InvalidPositionChangeDirection();
            }
            _checkPositionMinDelta(absChange, affectedTokensValueBefore - affectedTokensValueAfter, maxLossBps);
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
        } else if (!$._baseTokens.contains(order.outputToken)) {
            revert InvalidOutputToken();
        }

        uint256 valBefore;
        bool isInputBaseToken = $._baseTokens.contains(order.inputToken);
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
    function cancelAllowedInstrRootUpdate() external override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        if ($._pendingTimelockExpiry == 0 || block.timestamp >= $._pendingTimelockExpiry) {
            revert NoPendingUpdate();
        }
        emit NewAllowedInstrRootCancelled($._pendingAllowedInstrRoot);
        delete $._pendingAllowedInstrRoot;
        delete $._pendingTimelockExpiry;
    }

    /// @inheritdoc ICaliber
    function setMaxPositionIncreaseLossBps(uint256 newMaxPositionIncreaseLossBps) external override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        emit MaxPositionIncreaseLossBpsChanged($._maxPositionIncreaseLossBps, newMaxPositionIncreaseLossBps);
        $._maxPositionIncreaseLossBps = newMaxPositionIncreaseLossBps;
    }

    /// @inheritdoc ICaliber
    function setMaxPositionDecreaseLossBps(uint256 newMaxPositionDecreaseLossBps) external override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        emit MaxPositionDecreaseLossBpsChanged($._maxPositionDecreaseLossBps, newMaxPositionDecreaseLossBps);
        $._maxPositionDecreaseLossBps = newMaxPositionDecreaseLossBps;
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
            new BeaconProxy(
                mailboxBeacon, abi.encodeCall(ICaliberMailbox.initialize, (hubMachineEndpoint, address(this)))
            )
        );
        emit MailboxDeployed(_mailbox);
        return _mailbox;
    }

    /// @dev Adds a new base token to storage.
    function _addBaseToken(address token) internal {
        CaliberStorage storage $ = _getCaliberStorage();

        if (token == address(0)) {
            revert ZeroTokenAddress();
        }
        if (!$._baseTokens.add(token)) {
            revert BaseTokenAlreadyExists();
        }

        emit BaseTokenAdded(token);

        // Reverts if no price feed is registered for token in the oracle registry.
        IOracleRegistry(IBaseMakinaRegistry(registry).oracleRegistry()).getTokenFeedData(token);
    }

    /// @dev Computes the accounting value of a position. Depending on last and current value, the
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
            if (!$._baseTokens.contains(token)) {
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

    /// @dev Checks that absolute position value change is greater than minimum value relative to affected token balance changes and loss tolerance.
    function _checkPositionMinDelta(uint256 positionValChange, uint256 affectedTokensValChange, uint256 maxLossBps)
        internal
        pure
    {
        uint256 minChange = affectedTokensValChange.mulDiv(MAX_BPS - maxLossBps, MAX_BPS);
        if (positionValChange < minChange) {
            revert MaxValueLossExceeded();
        }
    }

    /// @dev Checks that absolute position value change is less than maximum value relative to affected token balance changes and loss tolerance.
    function _checkPositionMaxDelta(uint256 positionValChange, uint256 affectedTokensValChange, uint256 maxLossBps)
        internal
        pure
    {
        uint256 maxChange = affectedTokensValChange.mulDiv(MAX_BPS + maxLossBps, MAX_BPS);
        if (positionValChange > maxChange) {
            revert MaxValueLossExceeded();
        }
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

    /// @dev Executes a set of commands on the Weiroll VM, via a delegatecall.
    /// @param commands The commands to execute.
    /// @param state The state to pass to the VM.
    /// @return outState The new state after executing the commands.
    function _execute(bytes32[] calldata commands, bytes[] memory state) internal returns (bytes[] memory) {
        bytes memory returndata =
            Address.functionDelegateCall(weirollVm, abi.encodeCall(IWeirollVM.execute, (commands, state)));
        return abi.decode(returndata, (bytes[]));
    }
}
