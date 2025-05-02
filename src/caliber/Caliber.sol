// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IWeirollVM} from "../interfaces/IWeirollVM.sol";
import {IBaseMakinaRegistry} from "../interfaces/IBaseMakinaRegistry.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {IMachineEndpoint} from "../interfaces/IMachineEndpoint.sol";
import {IMakinaGovernable} from "../interfaces/IMakinaGovernable.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";
import {ISwapModule} from "../interfaces/ISwapModule.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";

contract Caliber is MakinaContext, AccessManagedUpgradeable, ReentrancyGuardUpgradeable, ICaliber {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20Metadata;

    /// @dev Full scale value in basis points.
    uint256 private constant MAX_BPS = 10_000;

    /// @dev Flag to indicate end of values in the accounting output state.
    bytes32 private constant ACCOUNTING_OUTPUT_STATE_END = bytes32(type(uint256).max);

    /// @inheritdoc ICaliber
    address public immutable weirollVm;

    /// @custom:storage-location erc7201:makina.storage.Caliber
    struct CaliberStorage {
        address _hubMachineEndpoint;
        address _accountingToken;
        uint256 _positionStaleThreshold;
        bytes32 _allowedInstrRoot;
        uint256 _timelockDuration;
        bytes32 _pendingAllowedInstrRoot;
        uint256 _pendingTimelockExpiry;
        uint256 _maxPositionIncreaseLossBps;
        uint256 _maxPositionDecreaseLossBps;
        uint256 _maxSwapLossBps;
        uint256 _managedPositionId;
        bool _isManagedPositionDebt;
        bool _isManagingFlashloan;
        uint256 _cooldownDuration;
        uint256 _lastBTSwapTimestamp;
        mapping(bytes32 => uint256) _lastExecutionTimestamp;
        mapping(uint256 posId => Position pos) _positionById;
        EnumerableSet.UintSet _positionIds;
        EnumerableSet.AddressSet _baseTokens;
        EnumerableSet.AddressSet _instrRootGuardians;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.Caliber")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CaliberStorageLocation = 0x32461bf02c7aa4aa351cd04411b6c7b9348073fbccf471c7b347bdaada044b00;

    function _getCaliberStorage() private pure returns (CaliberStorage storage $) {
        assembly {
            $.slot := CaliberStorageLocation
        }
    }

    constructor(address _registry, address _weirollVm) MakinaContext(_registry) {
        weirollVm = _weirollVm;
        _disableInitializers();
    }

    /// @inheritdoc ICaliber
    function initialize(CaliberInitParams calldata cParams, address _accountingToken, address _hubMachineEndpoint)
        external
        override
        initializer
    {
        CaliberStorage storage $ = _getCaliberStorage();

        $._accountingToken = _accountingToken;
        $._hubMachineEndpoint = _hubMachineEndpoint;
        $._positionStaleThreshold = cParams.initialPositionStaleThreshold;
        $._allowedInstrRoot = cParams.initialAllowedInstrRoot;
        $._timelockDuration = cParams.initialTimelockDuration;
        $._maxPositionIncreaseLossBps = cParams.initialMaxPositionIncreaseLossBps;
        $._maxPositionDecreaseLossBps = cParams.initialMaxPositionDecreaseLossBps;
        $._maxSwapLossBps = cParams.initialMaxSwapLossBps;
        $._cooldownDuration = cParams.initialCooldownDuration;
        _addBaseToken(_accountingToken);

        __ReentrancyGuard_init();
    }

    modifier onlyOperator() {
        IMakinaGovernable _hubMachineEndpoint = IMakinaGovernable(_getCaliberStorage()._hubMachineEndpoint);
        if (
            msg.sender
                != (
                    _hubMachineEndpoint.recoveryMode()
                        ? _hubMachineEndpoint.securityCouncil()
                        : _hubMachineEndpoint.mechanic()
                )
        ) {
            revert UnauthorizedCaller();
        }
        _;
    }

    modifier onlyRiskManager() {
        if (msg.sender != IMakinaGovernable(_getCaliberStorage()._hubMachineEndpoint).riskManager()) {
            revert UnauthorizedCaller();
        }
        _;
    }

    modifier onlyRiskManagerTimelock() {
        if (msg.sender != IMakinaGovernable(_getCaliberStorage()._hubMachineEndpoint).riskManagerTimelock()) {
            revert UnauthorizedCaller();
        }
        _;
    }

    /// @inheritdoc IAccessManaged
    function authority() public view override returns (address) {
        return IAccessManaged(_getCaliberStorage()._hubMachineEndpoint).authority();
    }

    /// @inheritdoc ICaliber
    function hubMachineEndpoint() external view override returns (address) {
        return _getCaliberStorage()._hubMachineEndpoint;
    }

    /// @inheritdoc ICaliber
    function accountingToken() external view override returns (address) {
        return _getCaliberStorage()._accountingToken;
    }

    /// @inheritdoc ICaliber
    function positionStaleThreshold() external view override returns (uint256) {
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
    function timelockDuration() external view override returns (uint256) {
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
    function maxPositionIncreaseLossBps() external view override returns (uint256) {
        return _getCaliberStorage()._maxPositionIncreaseLossBps;
    }

    /// @inheritdoc ICaliber
    function maxPositionDecreaseLossBps() external view override returns (uint256) {
        return _getCaliberStorage()._maxPositionDecreaseLossBps;
    }

    /// @inheritdoc ICaliber
    function maxSwapLossBps() external view override returns (uint256) {
        return _getCaliberStorage()._maxSwapLossBps;
    }

    /// @inheritdoc ICaliber
    function cooldownDuration() external view returns (uint256) {
        return _getCaliberStorage()._cooldownDuration;
    }

    /// @inheritdoc ICaliber
    function getPositionsLength() external view override returns (uint256) {
        return _getCaliberStorage()._positionIds.length();
    }

    /// @inheritdoc ICaliber
    function getPositionId(uint256 idx) external view override returns (uint256) {
        return _getCaliberStorage()._positionIds.at(idx);
    }

    /// @inheritdoc ICaliber
    function getPosition(uint256 posId) external view override returns (Position memory) {
        return _getCaliberStorage()._positionById[posId];
    }

    /// @inheritdoc ICaliber
    function isBaseToken(address token) external view override returns (bool) {
        return _getCaliberStorage()._baseTokens.contains(token);
    }

    /// @inheritdoc ICaliber
    function getBaseTokensLength() external view override returns (uint256) {
        return _getCaliberStorage()._baseTokens.length();
    }

    /// @inheritdoc ICaliber
    function getBaseToken(uint256 idx) external view override returns (address) {
        return _getCaliberStorage()._baseTokens.at(idx);
    }

    /// @inheritdoc ICaliber
    function isInstrRootGuardian(address user) external view override returns (bool) {
        CaliberStorage storage $ = _getCaliberStorage();
        return user == IMakinaGovernable($._hubMachineEndpoint).riskManager()
            || user == IMakinaGovernable($._hubMachineEndpoint).securityCouncil() || $._instrRootGuardians.contains(user);
    }

    /// @inheritdoc ICaliber
    function addBaseToken(address token) external override onlyRiskManagerTimelock {
        _addBaseToken(token);
    }

    /// @inheritdoc ICaliber
    function removeBaseToken(address token) external override onlyRiskManagerTimelock {
        CaliberStorage storage $ = _getCaliberStorage();

        if (token == $._accountingToken) {
            revert AccountingToken();
        }
        if (!$._baseTokens.remove(token)) {
            revert NotBaseToken();
        }
        if (IERC20Metadata(token).balanceOf(address(this)) > 0) {
            revert NonZeroBalance();
        }

        emit BaseTokenRemoved(token);
    }

    /// @inheritdoc ICaliber
    function accountForPosition(Instruction calldata instruction) external override returns (uint256, int256) {
        CaliberStorage storage $ = _getCaliberStorage();
        if (!$._positionIds.contains(instruction.positionId)) {
            revert PositionDoesNotExist();
        }
        return _accountForPosition(instruction, true);
    }

    /// @inheritdoc ICaliber
    function accountForPositionBatch(Instruction[] calldata instructions) external override {
        CaliberStorage storage $ = _getCaliberStorage();
        uint256 len = instructions.length;
        for (uint256 i; i < len; i++) {
            if (!$._positionIds.contains(instructions[i].positionId)) {
                revert PositionDoesNotExist();
            }
            _accountForPosition(instructions[i], true);
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
            if (currentTimestamp - $._positionById[posId].lastAccountingTime >= $._positionStaleThreshold) {
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
    function managePosition(Instruction calldata mgmtInstruction, Instruction calldata acctInstruction)
        public
        override
        nonReentrant
        onlyOperator
        returns (uint256, int256)
    {
        return _managePosition(mgmtInstruction, acctInstruction);
    }

    /// @inheritdoc ICaliber
    function managePositionBatch(Instruction[] calldata mgmtInstructions, Instruction[] calldata acctInstructions)
        external
        override
        nonReentrant
        onlyOperator
    {
        uint256 len = mgmtInstructions.length;
        if (len != acctInstructions.length) {
            revert MismatchedLengths();
        }
        for (uint256 i; i < len;) {
            _managePosition(mgmtInstructions[i], acctInstructions[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ICaliber
    function manageFlashLoan(Instruction calldata instruction, address token, uint256 amount) external override {
        CaliberStorage storage $ = _getCaliberStorage();

        if ($._isManagingFlashloan) {
            revert ManageFlashLoanReentrantCall();
        }

        address _flashLoanModule = IBaseMakinaRegistry(registry).flashLoanModule();
        if (msg.sender != _flashLoanModule) {
            revert NotFlashLoanModule();
        }
        if ($._managedPositionId == 0) {
            revert DirectManageFlashLoanCall();
        }
        if (instruction.instructionType != InstructionType.FLASHLOAN_MANAGEMENT) {
            revert InvalidInstructionType();
        }
        if ($._managedPositionId != instruction.positionId || $._isManagedPositionDebt != instruction.isDebt) {
            revert UnmatchingInstructions();
        }
        if (instruction.isDebt) {
            revert InvalidDebtFlag();
        }
        $._isManagingFlashloan = true;
        IERC20Metadata(token).safeTransferFrom(_flashLoanModule, address(this), amount);
        _checkInstructionIsAllowed(instruction);
        _execute(instruction.commands, instruction.state);
        IERC20Metadata(token).safeTransfer(_flashLoanModule, amount);
        $._isManagingFlashloan = false;
    }

    /// @inheritdoc ICaliber
    function harvest(Instruction calldata instruction, ISwapModule.SwapOrder[] calldata swapOrders)
        external
        override
        nonReentrant
        onlyOperator
    {
        if (instruction.instructionType != InstructionType.HARVEST) {
            revert InvalidInstructionType();
        }
        _checkInstructionIsAllowed(instruction);
        _execute(instruction.commands, instruction.state);
        for (uint256 i; i < swapOrders.length; i++) {
            _swap(swapOrders[i]);
        }
    }

    /// @inheritdoc ICaliber
    function swap(ISwapModule.SwapOrder calldata order) external override nonReentrant onlyOperator {
        _swap(order);
    }

    /// @inheritdoc ICaliber
    function transferToHubMachine(address token, uint256 amount, bytes calldata data) external override onlyOperator {
        CaliberStorage storage $ = _getCaliberStorage();
        IERC20Metadata(token).forceApprove($._hubMachineEndpoint, amount);
        IMachineEndpoint($._hubMachineEndpoint).manageTransfer(token, amount, data);
        emit TransferToHubMachine(token, amount);
    }

    /// @inheritdoc ICaliber
    function setPositionStaleThreshold(uint256 newPositionStaleThreshold) external override onlyRiskManagerTimelock {
        CaliberStorage storage $ = _getCaliberStorage();
        emit PositionStaleThresholdChanged($._positionStaleThreshold, newPositionStaleThreshold);
        $._positionStaleThreshold = newPositionStaleThreshold;
    }

    /// @inheritdoc ICaliber
    function setTimelockDuration(uint256 newTimelockDuration) external override onlyRiskManagerTimelock {
        CaliberStorage storage $ = _getCaliberStorage();
        emit TimelockDurationChanged($._timelockDuration, newTimelockDuration);
        $._timelockDuration = newTimelockDuration;
    }

    /// @inheritdoc ICaliber
    function scheduleAllowedInstrRootUpdate(bytes32 newAllowedInstrRoot) external override onlyRiskManager {
        CaliberStorage storage $ = _getCaliberStorage();
        _updateAllowedInstrRoot();
        if ($._pendingTimelockExpiry != 0) {
            revert ActiveUpdatePending();
        }
        if (newAllowedInstrRoot == $._allowedInstrRoot) {
            revert SameRoot();
        }
        $._pendingAllowedInstrRoot = newAllowedInstrRoot;
        $._pendingTimelockExpiry = block.timestamp + $._timelockDuration;
        emit NewAllowedInstrRootScheduled(newAllowedInstrRoot, $._pendingTimelockExpiry);
    }

    /// @inheritdoc ICaliber
    function cancelAllowedInstrRootUpdate() external override {
        CaliberStorage storage $ = _getCaliberStorage();
        IMachineEndpoint _hubMachineEndpoint = IMachineEndpoint($._hubMachineEndpoint);
        if (
            msg.sender != _hubMachineEndpoint.riskManager() && msg.sender != _hubMachineEndpoint.securityCouncil()
                && !_getCaliberStorage()._instrRootGuardians.contains(msg.sender)
        ) {
            revert UnauthorizedCaller();
        }
        if ($._pendingTimelockExpiry == 0 || block.timestamp >= $._pendingTimelockExpiry) {
            revert NoPendingUpdate();
        }
        emit NewAllowedInstrRootCancelled($._pendingAllowedInstrRoot);
        delete $._pendingAllowedInstrRoot;
        delete $._pendingTimelockExpiry;
    }

    /// @inheritdoc ICaliber
    function setMaxPositionIncreaseLossBps(uint256 newMaxPositionIncreaseLossBps)
        external
        override
        onlyRiskManagerTimelock
    {
        CaliberStorage storage $ = _getCaliberStorage();
        emit MaxPositionIncreaseLossBpsChanged($._maxPositionIncreaseLossBps, newMaxPositionIncreaseLossBps);
        $._maxPositionIncreaseLossBps = newMaxPositionIncreaseLossBps;
    }

    /// @inheritdoc ICaliber
    function setMaxPositionDecreaseLossBps(uint256 newMaxPositionDecreaseLossBps)
        external
        override
        onlyRiskManagerTimelock
    {
        CaliberStorage storage $ = _getCaliberStorage();
        emit MaxPositionDecreaseLossBpsChanged($._maxPositionDecreaseLossBps, newMaxPositionDecreaseLossBps);
        $._maxPositionDecreaseLossBps = newMaxPositionDecreaseLossBps;
    }

    /// @inheritdoc ICaliber
    function setMaxSwapLossBps(uint256 newMaxSwapLossBps) external override onlyRiskManagerTimelock {
        CaliberStorage storage $ = _getCaliberStorage();
        emit MaxSwapLossBpsChanged($._maxSwapLossBps, newMaxSwapLossBps);
        $._maxSwapLossBps = newMaxSwapLossBps;
    }

    /// @inheritdoc ICaliber
    function setCooldownDuration(uint256 newCooldownDuration) external override onlyRiskManagerTimelock {
        CaliberStorage storage $ = _getCaliberStorage();
        emit CooldownDurationChanged($._cooldownDuration, newCooldownDuration);
        $._cooldownDuration = newCooldownDuration;
    }

    /// @inheritdoc ICaliber
    function addInstrRootGuardian(address newGuardian) external override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        IMachineEndpoint _hubMachineEndpoint = IMachineEndpoint($._hubMachineEndpoint);
        if (
            newGuardian == _hubMachineEndpoint.riskManager() || newGuardian == _hubMachineEndpoint.securityCouncil()
                || !$._instrRootGuardians.add(newGuardian)
        ) {
            revert AlreadyRootGuardian();
        }
        emit InstrRootGuardianAdded(newGuardian);
    }

    /// @inheritdoc ICaliber
    function removeInstrRootGuardian(address guardian) external override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        IMachineEndpoint _hubMachineEndpoint = IMachineEndpoint($._hubMachineEndpoint);
        if (guardian == _hubMachineEndpoint.riskManager() || guardian == _hubMachineEndpoint.securityCouncil()) {
            revert ProtectedRootGuardian();
        }
        if (!$._instrRootGuardians.remove(guardian)) {
            revert NotRootGuardian();
        }
        emit InstrRootGuardianRemoved(guardian);
    }

    /// @dev Adds a new base token to storage.
    function _addBaseToken(address token) internal {
        CaliberStorage storage $ = _getCaliberStorage();

        if (token == address(0)) {
            revert ZeroTokenAddress();
        }
        if (!$._baseTokens.add(token)) {
            revert AlreadyBaseToken();
        }

        emit BaseTokenAdded(token);

        if (!IOracleRegistry(IBaseMakinaRegistry(registry).oracleRegistry()).isFeedRouteRegistered(token)) {
            revert IOracleRegistry.PriceFeedRouteNotRegistered(token);
        }
    }

    /// @dev Manages and accounts for a position by executing the provided instructions.
    function _managePosition(Instruction calldata mgmtInstruction, Instruction calldata acctInstruction)
        internal
        returns (uint256, int256)
    {
        CaliberStorage storage $ = _getCaliberStorage();

        uint256 posId = mgmtInstruction.positionId;
        if (posId == 0) {
            revert ZeroPositionId();
        }
        if (posId != acctInstruction.positionId || mgmtInstruction.isDebt != acctInstruction.isDebt) {
            revert UnmatchingInstructions();
        }
        if (mgmtInstruction.instructionType != InstructionType.MANAGEMENT) {
            revert InvalidInstructionType();
        }

        $._managedPositionId = posId;
        $._isManagedPositionDebt = mgmtInstruction.isDebt;

        _accountForPosition(acctInstruction, true);

        _checkInstructionIsAllowed(mgmtInstruction);

        uint256 affectedTokensValueBefore;
        for (uint256 i; i < mgmtInstruction.affectedTokens.length; i++) {
            address _affectedToken = mgmtInstruction.affectedTokens[i];
            if (!$._baseTokens.contains(_affectedToken)) {
                revert InvalidAffectedToken();
            }
            affectedTokensValueBefore +=
                _accountingValueOf(_affectedToken, IERC20Metadata(_affectedToken).balanceOf(address(this)));
        }

        _execute(mgmtInstruction.commands, mgmtInstruction.state);

        (uint256 value, int256 change) = _accountForPosition(acctInstruction, false);

        uint256 affectedTokensValueAfter;
        for (uint256 i; i < mgmtInstruction.affectedTokens.length; i++) {
            address _affectedToken = mgmtInstruction.affectedTokens[i];
            affectedTokensValueAfter +=
                _accountingValueOf(_affectedToken, IERC20Metadata(_affectedToken).balanceOf(address(this)));
        }

        bool isBaseTokenInflow = affectedTokensValueAfter >= affectedTokensValueBefore;
        bool isPositionIncrease = change >= 0;
        uint256 absChange = isPositionIncrease ? uint256(change) : uint256(-change);
        uint256 maxLossBps = isPositionIncrease ? $._maxPositionIncreaseLossBps : $._maxPositionDecreaseLossBps;

        if (isPositionIncrease && IMachineEndpoint($._hubMachineEndpoint).recoveryMode()) {
            revert RecoveryMode();
        }

        bytes32 executionHash = keccak256(abi.encodePacked(posId, mgmtInstruction.commands, isPositionIncrease));
        if (block.timestamp - $._lastExecutionTimestamp[executionHash] < $._cooldownDuration) {
            revert OngoingCooldown();
        }

        if (isBaseTokenInflow) {
            if (mgmtInstruction.isDebt == isPositionIncrease) {
                _checkPositionMaxDelta(absChange, affectedTokensValueAfter - affectedTokensValueBefore, maxLossBps);
            }
        } else {
            if (mgmtInstruction.isDebt == isPositionIncrease) {
                revert InvalidPositionChangeDirection();
            }
            _checkPositionMinDelta(absChange, affectedTokensValueBefore - affectedTokensValueAfter, maxLossBps);
        }

        $._lastExecutionTimestamp[executionHash] = block.timestamp;
        $._managedPositionId = 0;
        $._isManagedPositionDebt = false;

        return (value, change);
    }

    /// @dev Computes the accounting value of a position. Depending on last and current value, the
    ///      position is then either created, closed or simply updated in storage.
    function _accountForPosition(Instruction calldata instruction, bool checks) internal returns (uint256, int256) {
        if (checks) {
            if (instruction.instructionType != InstructionType.ACCOUNTING) {
                revert InvalidInstructionType();
            }
            _checkInstructionIsAllowed(instruction);
        }

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
            currentValue += _accountingValueOf(token, amounts[i]);
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
            if (bytes32(state[i]) == ACCOUNTING_OUTPUT_STATE_END) {
                break;
            }
            amounts[i] = uint256(bytes32(state[i]));
            count++;
        }

        // Resize the array to the actual number of values.
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

    /// @dev Checks if the given instruction is allowed by verifying its Merkle proof against the allowed instructions root.
    /// @param instruction The instruction to check.
    function _checkInstructionIsAllowed(Instruction calldata instruction) internal {
        bytes32 commandsHash = keccak256(abi.encodePacked(instruction.commands));
        bytes32 stateHash = _getStateHash(instruction.state, instruction.stateBitmap);
        bytes32 affectedTokensHash = keccak256(abi.encodePacked(instruction.affectedTokens));
        bytes32 instructionLeaf = keccak256(
            abi.encode(
                keccak256(
                    abi.encode(
                        commandsHash,
                        stateHash,
                        instruction.stateBitmap,
                        instruction.positionId,
                        instruction.isDebt,
                        affectedTokensHash,
                        instruction.instructionType
                    )
                )
            )
        );
        if (!MerkleProof.verify(instruction.merkleProof, _updateAllowedInstrRoot(), instructionLeaf)) {
            revert InvalidInstructionProof();
        }
    }

    /// @dev Computes a hash of the state array, selectively including elements as specified by a bitmap.
    ///      This enables a weiroll script to have both fixed and variable parameters.
    /// @param state The state array to hash.
    /// @param bitmap The bitmap where each bit determines whether the corresponding element in state is included or ignored in the hash computation.
    /// @return hash The hash of the state array.
    function _getStateHash(bytes[] calldata state, uint128 bitmap) internal pure returns (bytes32) {
        if (bitmap == uint128(0)) {
            return bytes32(0);
        }

        uint8 i;
        bytes memory hashInput;

        // Iterate through the state and hash values corresponding to indices marked in the bitmap.
        for (i; i < state.length;) {
            // If the bit is set as 1, hash the state value.
            if (bitmap & (0x80000000000000000000000000000000 >> i) != 0) {
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

    function _swap(ISwapModule.SwapOrder calldata order) internal {
        CaliberStorage storage $ = _getCaliberStorage();
        if (IMachineEndpoint($._hubMachineEndpoint).recoveryMode() && order.outputToken != $._accountingToken) {
            revert RecoveryMode();
        } else if (!$._baseTokens.contains(order.outputToken)) {
            revert InvalidOutputToken();
        }

        uint256 valBefore;
        bool isInputBaseToken = $._baseTokens.contains(order.inputToken);
        if (isInputBaseToken) {
            if (block.timestamp - $._lastBTSwapTimestamp < $._cooldownDuration) {
                revert OngoingCooldown();
            }
            valBefore = _accountingValueOf(order.inputToken, order.inputAmount);
        }

        address _swapModule = IBaseMakinaRegistry(registry).swapModule();
        IERC20Metadata(order.inputToken).forceApprove(_swapModule, order.inputAmount);
        uint256 amountOut = ISwapModule(_swapModule).swap(order);
        IERC20Metadata(order.inputToken).forceApprove(_swapModule, 0);

        if (isInputBaseToken) {
            uint256 valAfter = _accountingValueOf(order.outputToken, amountOut);
            if (valAfter < valBefore.mulDiv(MAX_BPS - $._maxSwapLossBps, MAX_BPS)) {
                revert MaxValueLossExceeded();
            }
            $._lastBTSwapTimestamp = block.timestamp;
        }
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
