// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./BaseTest.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ICaliber} from "../src/interfaces/ICaliber.sol";
import {IOracleRegistry} from "../src/interfaces/IOracleRegistry.sol";
import {ISwapper} from "../src/interfaces/ISwapper.sol";
import {WeirollPlanner} from "./utils/WeirollPlanner.sol";
import {MockERC4626} from "./mocks/MockERC4626.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";
import {MockPool} from "./mocks/MockPool.sol";

contract CaliberTest is BaseTest {
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

    bytes32 private constant ACCOUNTING_OUTPUT_STATE_END_OF_ARGS = bytes32(type(uint256).max);

    /// @dev A is the accounting token, B is the base token
    /// and E is the reference currency of the oracle registry
    uint256 private constant PRICE_A_E = 150;
    uint256 private constant PRICE_B_E = 60000;
    uint256 private constant PRICE_B_A = 400;

    uint256 private constant BASE_TOKEN_POS_ID = 2;
    uint256 private constant VAULT_POS_ID = 3;
    uint256 private constant POOL_POS_ID = 4;

    MockERC20 private baseToken;
    MockERC4626 private vault;
    MockPool private pool;

    MockPriceFeed private bPriceFeed1;
    MockPriceFeed private aPriceFeed1;

    function _setUp() public override {
        baseToken = new MockERC20("baseToken", "BT", 18);
        vault = new MockERC4626("vault", "VLT", IERC20(baseToken), 0);

        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);
        bPriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_E * 1e18), block.timestamp);

        pool = new MockPool(address(accountingToken), address(baseToken), "MockPool", "MP");

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(bPriceFeed1), 2 * DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        swapper.setDexAggregatorTargets(ISwapper.DexAggregator.ZEROX, address(pool), address(pool));
        vm.stopPrank();

        caliber = _deployCaliber(address(0), address(accountingToken), accountingTokenPosId, bytes32(0));

        // generate merkle tree for instructions involving mock base token and vault
        _generateMerkleData(
            address(caliber),
            address(accountingToken),
            address(baseToken),
            address(vault),
            VAULT_POS_ID,
            address(pool),
            POOL_POS_ID
        );

        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(_getAllowedInstrMerkleRoot());
        skip(caliber.timelockDuration() + 1);
    }

    function test_caliber_getters() public view {
        assertNotEq(caliber.inbox(), address(0));
        assertEq(caliber.mechanic(), mechanic);
        assertEq(caliber.securityCouncil(), securityCouncil);
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.lastReportedAUM(), 0);
        assertEq(caliber.lastReportedAUMTime(), 0);
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
        assertEq(caliber.recoveryMode(), false);
        assertEq(caliber.allowedInstrRoot(), _getAllowedInstrMerkleRoot());
        assertEq(caliber.timelockDuration(), 1 hours);
        assertEq(caliber.pendingAllowedInstrRoot(), bytes32(0));
        assertEq(caliber.pendingTimelockExpiry(), 0);
        assertEq(caliber.maxMgmtLossBps(), DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS);
        assertEq(caliber.maxSwapLossBps(), DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS);
        assertEq(caliber.isBaseToken(address(accountingToken)), true);
        assertEq(caliber.getPositionsLength(), 1);
    }

    function test_cannotAddBaseTokenWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);
    }

    function test_addBaseToken() public {
        vm.expectEmit(true, true, false, true, address(caliber));
        emit PositionCreated(BASE_TOKEN_POS_ID);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        assertEq(caliber.isBaseToken(address(baseToken)), true);
        assertEq(caliber.getPositionsLength(), 2);
        assertEq(caliber.getPositionId(1), BASE_TOKEN_POS_ID);
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).lastAccountingTime, 0);
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).value, 0);
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).isBaseToken, true);
    }

    function test_cannotAddBaseTokenWithSamePosIdTwice() public {
        vm.startPrank(dao);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken), accountingTokenPosId);

        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        MockERC20 baseToken2 = new MockERC20("Base Token 2", "BT2", 18);
        oracleRegistry.setTokenFeedData(
            address(baseToken2), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken2), BASE_TOKEN_POS_ID);
    }

    function test_cannotAddSameBaseTokenTwice() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        vm.expectRevert(ICaliber.BaseTokenAlreadyExists.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID + 1);
    }

    function test_cannotAddBaseTokenWithZeroId() public {
        vm.expectRevert(ICaliber.ZeroPositionId.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 0);
    }

    function test_cannotAddBaseTokenWithoutRegisteredFeed() public {
        MockERC20 baseToken2;
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken2), BASE_TOKEN_POS_ID + 1);
    }

    function test_accountForATPosition() public {
        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, 0);

        (uint256 value, int256 change) = caliber.accountForBaseToken(1);

        assertEq(value, 0);
        assertEq(change, 0);
        assertEq(caliber.getPosition(1).value, value);
        assertEq(caliber.getPosition(1).lastAccountingTime, block.timestamp);

        deal(address(accountingToken), address(caliber), 1e18, true);

        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, block.timestamp);

        (value, change) = caliber.accountForBaseToken(1);

        assertEq(value, 1e18);
        assertEq(change, 1e18);
        assertEq(caliber.getPosition(1).value, value);
        assertEq(caliber.getPosition(1).lastAccountingTime, block.timestamp);
    }

    function test_accountForBTPosition() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).value, 0);
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).lastAccountingTime, 0);

        (uint256 value, int256 change) = caliber.accountForBaseToken(BASE_TOKEN_POS_ID);

        assertEq(value, 0);
        assertEq(change, 0);
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).value, value);
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).lastAccountingTime, block.timestamp);

        deal(address(baseToken), address(caliber), 1e18, true);

        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).value, 0);
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).lastAccountingTime, block.timestamp);

        (value, change) = caliber.accountForBaseToken(BASE_TOKEN_POS_ID);

        assertEq(value, 1e18 * PRICE_B_A);
        assertEq(change, int256(1e18 * PRICE_B_A));
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).value, value);
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).lastAccountingTime, block.timestamp);

        uint256 newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        deal(address(baseToken), address(caliber), 3e18, true);
        // this should not affect the accounting
        deal(address(accountingToken), address(caliber), 10e18, true);

        (value, change) = caliber.accountForBaseToken(BASE_TOKEN_POS_ID);

        assertEq(value, 3e18 * PRICE_B_A);
        assertEq(change, int256(2e18 * PRICE_B_A));
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).value, value);
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).lastAccountingTime, newTimestamp);

        newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        deal(address(baseToken), address(caliber), 2e18, true);

        (value, change) = caliber.accountForBaseToken(BASE_TOKEN_POS_ID);

        assertEq(value, 2e18 * PRICE_B_A);
        assertEq(change, -1 * int256(1e18 * PRICE_B_A));
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).value, value);
        assertEq(caliber.getPosition(BASE_TOKEN_POS_ID).lastAccountingTime, newTimestamp);
    }

    function test_cannotAccountForUnexistingBTPosition() public {
        vm.prank(dao);

        vm.expectRevert(ICaliber.NotBaseTokenPosition.selector);
        caliber.accountForBaseToken(BASE_TOKEN_POS_ID);
    }

    function test_cannotSetMechanicWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMechanic(address(0x0));
    }

    function test_setMechanic() public {
        address newMechanic = makeAddr("NewMechanic");
        vm.expectEmit(true, true, false, true, address(caliber));
        emit MechanicChanged(mechanic, newMechanic);
        vm.prank(dao);
        caliber.setMechanic(newMechanic);
        assertEq(caliber.mechanic(), newMechanic);
    }

    function test_cannotSetSecurityCouncilWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setSecurityCouncil(address(0x0));
    }

    function test_setSecurityCouncil() public {
        address newSecurityCouncil = makeAddr("NewSecurityCouncil");
        vm.expectEmit(true, true, false, true, address(caliber));
        emit SecurityCouncilChanged(securityCouncil, newSecurityCouncil);
        vm.prank(dao);
        caliber.setSecurityCouncil(newSecurityCouncil);
        assertEq(caliber.securityCouncil(), newSecurityCouncil);
    }

    function test_cannotSetPositionStaleThresholdWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setPositionStaleThreshold(2 hours);
    }

    function test_setPositionStaleThreshold() public {
        uint256 newThreshold = 2 hours;
        emit PositionStaleThresholdChanged(DEFAULT_CALIBER_POS_STALE_THRESHOLD, newThreshold);
        vm.prank(dao);
        caliber.setPositionStaleThreshold(newThreshold);
        assertEq(caliber.positionStaleThreshold(), newThreshold);
    }

    function test_cannotSetRecoveryModeWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setRecoveryMode(true);
    }

    function test_setRecoveryMode() public {
        vm.expectEmit(true, true, false, true, address(caliber));
        emit RecoveryModeChanged(true);
        vm.prank(dao);
        caliber.setRecoveryMode(true);
        assertTrue(caliber.recoveryMode());
    }

    function test_cannotSetTimelockDurationWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setTimelockDuration(2 hours);
    }

    function test_setTimelockDuration() public {
        uint256 newDuration = 2 hours;
        emit TimelockDurationChanged(DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK, newDuration);
        vm.prank(dao);
        caliber.setTimelockDuration(newDuration);
        assertEq(caliber.timelockDuration(), newDuration);
    }

    function test_cannotScheduleRootUpdateWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.scheduleAllowedInstrRootUpdate(bytes32(0));
    }

    function test_scheduleallowedInstrRootUpdate() public {
        bytes32 currentRoot = _getAllowedInstrMerkleRoot();

        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.expectEmit(true, true, false, true, address(caliber));
        emit NewAllowedInstrRootScheduled(newRoot, effectiveUpdateTime);
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        assertEq(caliber.allowedInstrRoot(), currentRoot);
        assertEq(caliber.pendingAllowedInstrRoot(), newRoot);
        assertEq(caliber.pendingTimelockExpiry(), effectiveUpdateTime);

        vm.warp(effectiveUpdateTime);

        assertEq(caliber.allowedInstrRoot(), newRoot);
        assertEq(caliber.pendingAllowedInstrRoot(), bytes32(0));
        assertEq(caliber.pendingTimelockExpiry(), 0);
    }

    function test_timelockDurationChangeDoesNotAffectPendingUpdate() public {
        assertEq(caliber.timelockDuration(), 1 hours);

        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.startPrank(dao);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);
        caliber.setTimelockDuration(2 hours);

        assertEq(caliber.pendingTimelockExpiry(), effectiveUpdateTime);

        vm.warp(effectiveUpdateTime);

        assertEq(caliber.allowedInstrRoot(), newRoot);
        assertEq(caliber.pendingAllowedInstrRoot(), bytes32(0));
        assertEq(caliber.pendingTimelockExpiry(), 0);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);
    }

    function test_cannotScheduleRootUpdateWithActivePendingUpdate() public {
        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        uint256 effectiveUpdateTime = block.timestamp + caliber.timelockDuration();

        vm.startPrank(dao);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.expectRevert(ICaliber.ActiveUpdatePending.selector);
        caliber.scheduleAllowedInstrRootUpdate(newRoot);

        vm.warp(effectiveUpdateTime);

        caliber.scheduleAllowedInstrRootUpdate(newRoot);
    }

    function test_cannotSetMaxMgmtLossBpsWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMaxMgmtLossBps(1000);
    }

    function test_setMaxMgmtLossBps() public {
        vm.expectEmit(true, true, true, true, address(caliber));
        emit MaxMgmtLossBpsChanged(DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS, 1000);
        vm.prank(dao);
        caliber.setMaxMgmtLossBps(1000);
        assertEq(caliber.maxMgmtLossBps(), 1000);
    }

    function test_cannotSetMaxSwapLossBpsWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setMaxSwapLossBps(1000);
    }

    function test_setMaxSwapLossBps() public {
        vm.expectEmit(true, true, true, true, address(caliber));
        emit MaxSwapLossBpsChanged(DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS, 1000);
        vm.prank(dao);
        caliber.setMaxSwapLossBps(1000);
        assertEq(caliber.maxSwapLossBps(), 1000);
    }

    function test_cannotManagePositionWithoutInstruction() public {
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        vm.prank(mechanic);
        caliber.managePosition(new ICaliber.Instruction[](0));
    }

    function test_cannotManagePositionWithInvalidInstruction() public {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        vm.startPrank(mechanic);

        // no instructions
        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](0);
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        caliber.managePosition(instructions);

        // missing second instruction
        instructions = new ICaliber.Instruction[](1);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        caliber.managePosition(instructions);

        // more than 2 instructions
        instructions = new ICaliber.Instruction[](3);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[2] = instructions[1];
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        caliber.managePosition(instructions);

        // instructions have different positionId
        instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), POOL_POS_ID, address(vault));
        vm.expectRevert(ICaliber.UnmatchingInstructions.selector);
        caliber.managePosition(instructions);

        // first instruction is not a manage instruction
        instructions[0] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.managePosition(instructions);

        // affected token list contains non-base-token
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[1].affectedTokens[0] = address(0);
        vm.expectRevert(ICaliber.InvalidAffectedToken.selector);
        caliber.managePosition(instructions);

        vm.stopPrank();

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        vm.startPrank(mechanic);

        // position is a base token position
        instructions[0] = _build4626DepositInstruction(address(caliber), BASE_TOKEN_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), BASE_TOKEN_POS_ID, address(vault));
        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        caliber.managePosition(instructions);

        // second instruction is not an accounting instruction
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithInvalidAccounting() public {
        // baseToken is not set as an actual base token in the caliber

        uint256 inputAmount = 3e18;

        deal(address(accountingToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _buildMockPoolAddLiquidityOneSide0Instruction(POOL_POS_ID, address(pool), inputAmount);
        instructions[1] = _buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool));

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.managePosition(instructions);

        // set baseToken as an actual base token
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        // replace end flag with null value in accounting output state
        delete instructions[1].state[1];
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithInvalidProof() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);

        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(baseToken), 0);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault2), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault2));
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong posId
        instructions[0] = _build4626DepositInstruction(address(caliber), POOL_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), POOL_POS_ID, address(vault));
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong affected tokens list
        instructions[0] = _build4626DepositInstruction(address(caliber), POOL_POS_ID, address(vault), inputAmount);
        instructions[0].affectedTokens[0] = address(0);
        instructions[1] = _build4626AccountingInstruction(address(caliber), POOL_POS_ID, address(vault));
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong commands
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[0].commands[1] = instructions[0].commands[0];
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong state
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[0].state[2] = instructions[0].state[0];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong bitmap
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[0].stateBitmap = 0;
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.managePosition(instructions);
    }

    function test_cannotManagePositionWithValueLossTooHigh() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);
        // a1 < 0.99 * (a0 + a1)
        // <=> a1 < (0.99 / 0.01) * a0
        uint256 assets0 = 1e30 * PRICE_B_A;
        uint256 assets1 = (1e30 * (10_000 - DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS) / DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS) - 1;
        deal(address(accountingToken), address(caliber), assets0, true);
        deal(address(baseToken), address(caliber), assets1, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _buildMockPoolAddLiquidityInstruction(POOL_POS_ID, address(pool), assets0, assets1);
        instructions[1] = _buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool));

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.MaxValueLossExceeded.selector);
        caliber.managePosition(instructions);
    }

    function test_managePosition_4626_create() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        assertEq(caliber.getPositionsLength(), 2);

        vm.expectEmit(true, true, false, true, address(caliber));
        emit PositionCreated(VAULT_POS_ID);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, inputAmount * PRICE_B_A);
    }

    function test_managePosition_4626_increase() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        assertEq(caliber.getPositionsLength(), 2);

        vm.startPrank(mechanic);
        caliber.managePosition(instructions);
        previewShares += vault.previewDeposit(inputAmount);
        caliber.managePosition(instructions);
        vm.stopPrank();

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, 2 * inputAmount * PRICE_B_A);
    }

    function test_managePosition_4626_decrease() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        assertEq(caliber.getPositionsLength(), 2);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        uint256 sharesToRedeem = vault.balanceOf(address(caliber)) / 2;

        instructions[0] = _build4626RedeemInstruction(address(caliber), VAULT_POS_ID, address(vault), sharesToRedeem);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares - sharesToRedeem);
        assertEq(
            caliber.getPosition(VAULT_POS_ID).value, vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A
        );
    }

    function test_managePosition_4626_close() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        assertEq(caliber.getPositionsLength(), 2);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        instructions[0] = _build4626RedeemInstruction(
            address(caliber), VAULT_POS_ID, address(vault), vault.balanceOf(address(caliber))
        );

        vm.expectEmit(true, true, false, true, address(caliber));
        emit PositionClosed(VAULT_POS_ID);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 2);
        assertEq(vault.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, 0);
    }

    function test_managePosition_mockPool_create() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);
        uint256 assets0 = 1e30 * PRICE_B_A;
        uint256 assets1 = 1e30 * (10_000 - DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS) / DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS;
        uint256 previewLpts = pool.previewAddLiquidity(assets0, assets1);

        deal(address(accountingToken), address(caliber), assets0, true);
        deal(address(baseToken), address(caliber), assets1, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _buildMockPoolAddLiquidityInstruction(POOL_POS_ID, address(pool), assets0, assets1);
        instructions[1] = _buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool));

        vm.expectEmit(true, true, false, true, address(caliber));
        emit PositionCreated(POOL_POS_ID);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(pool.balanceOf(address(caliber)), previewLpts);
        assertEq(caliber.getPosition(POOL_POS_ID).value, assets1 * PRICE_B_A);
    }

    function test_managePosition_mockPool_close() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);
        uint256 assets0 = 1e30 * PRICE_B_A;
        uint256 assets1 = 1e30 * (10_000 - DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS) / DEFAULT_CALIBER_MAX_MGMT_LOSS_BPS;

        deal(address(accountingToken), address(caliber), assets0, true);
        deal(address(baseToken), address(caliber), assets1, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _buildMockPoolAddLiquidityInstruction(POOL_POS_ID, address(pool), assets0, assets1);
        instructions[1] = _buildMockPoolAccountingInstruction(address(caliber), POOL_POS_ID, address(pool));

        assertEq(caliber.getPositionsLength(), 2);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        instructions[0] = _buildMockPoolRemoveLiquidityOneSide1Instruction(
            POOL_POS_ID, address(pool), pool.balanceOf(address(caliber))
        );

        vm.expectEmit(true, true, false, true, address(caliber));
        emit PositionClosed(POOL_POS_ID);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 2);
        assertEq(pool.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(POOL_POS_ID).value, 0);
    }

    function test_cannotManagePositionWithWrongRoot() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // schedule root update with a wrong root
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(keccak256(abi.encodePacked("wrongRoot")));

        // instruction can still be executed while the update is pending
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        skip(caliber.timelockDuration());

        // instruction cannot be executed after the update takes effect
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.managePosition(instructions);

        // schedule root update with the correct root
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(_getAllowedInstrMerkleRoot());

        // instruction cannot be executed while the update is pending
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.managePosition(instructions);

        skip(caliber.timelockDuration());

        // instruction can be executed after the update takes effect
        vm.prank(mechanic);
        caliber.managePosition(instructions);
    }

    function test_managePositionOperatorPermissions() public {
        // security council cannot call managePosition while recovery mode is off
        ICaliber.Instruction[] memory dummyInstructions;
        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.managePosition(dummyInstructions);

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        Caliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create a new position with mechanic
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // turn on recovery mode
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        // check mechanic now cannot call manage position
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.managePosition(dummyInstructions);

        // check security council cannot increase position
        uint256 previewShares = vault.previewDeposit(inputAmount);
        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.RecoveryMode.selector);
        caliber.managePosition(instructions);
        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, inputAmount * PRICE_B_A);

        // check security council can decrease position
        uint256 sharesToRedeem = vault.balanceOf(address(caliber)) / 2;
        instructions[0] = _build4626RedeemInstruction(address(caliber), VAULT_POS_ID, address(vault), sharesToRedeem);
        vm.prank(securityCouncil);
        caliber.managePosition(instructions);
        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares - sharesToRedeem);
        assertEq(
            caliber.getPosition(VAULT_POS_ID).value, vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A
        );

        // check that security council can close position
        instructions[0] = _build4626RedeemInstruction(
            address(caliber), VAULT_POS_ID, address(vault), vault.balanceOf(address(caliber))
        );
        vm.prank(securityCouncil);
        caliber.managePosition(instructions);
        assertEq(caliber.getPositionsLength(), 2);
        assertEq(vault.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, 0);
    }

    function test_cannotSwapIntoNonBaseToken() public {
        ISwapper.SwapOrder memory order;
        vm.expectRevert(ICaliber.InvalidOutputToken.selector);
        vm.prank(mechanic);
        caliber.swap(order);
    }

    function test_cannotSwapIntoNonAccountingTokenWhileInRecoveryMode() public {
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        ISwapper.SwapOrder memory order;
        vm.expectRevert(ICaliber.RecoveryMode.selector);
        vm.prank(securityCouncil);
        caliber.swap(order);
    }

    function test_cannotSwapWithoutMechanicWhileNotInRecoveryMode() public {
        ISwapper.SwapOrder memory order;

        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.swap(order);

        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.swap(order);
    }

    function test_cannotSwapWithoutSCWhileInRecoveryMode() public {
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        ISwapper.SwapOrder memory order;

        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.swap(order);

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.swap(order);
    }

    function test_swap() public {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        // swap baseToken to accountingToken
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        uint256 previewOutputAmoun1 = pool.previewSwap(address(baseToken), inputAmount);
        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), inputAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: inputAmount,
            minOutputAmount: previewOutputAmoun1
        });
        vm.prank(mechanic);
        caliber.swap(order);

        assertEq(accountingToken.balanceOf(address(caliber)), previewOutputAmoun1);
        assertEq(baseToken.balanceOf(address(caliber)), 0);

        // set baseToken as an actual base token
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        // swap accountingToken to baseToken
        uint256 previewOutputAmount2 = pool.previewSwap(address(accountingToken), previewOutputAmoun1);
        order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(accountingToken), previewOutputAmoun1)),
            inputToken: address(accountingToken),
            outputToken: address(baseToken),
            inputAmount: previewOutputAmoun1,
            minOutputAmount: previewOutputAmount2
        });
        vm.prank(mechanic);
        caliber.swap(order);

        assertEq(accountingToken.balanceOf(address(caliber)), 0);
        assertEq(baseToken.balanceOf(address(caliber)), previewOutputAmount2);
    }

    function test_swapWhileInRecoveryMode() public {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        // turn on recovery mode
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        // swap baseToken to accountingToken
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        uint256 previewOutputAmount1 = pool.previewSwap(address(baseToken), inputAmount);
        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), inputAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: inputAmount,
            minOutputAmount: previewOutputAmount1
        });
        vm.prank(securityCouncil);
        caliber.swap(order);
    }

    function test_cannotSwapFromBTWithValueLossTooHigh() public {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        // decrease accountingToken value
        aPriceFeed1.setLatestAnswer(
            aPriceFeed1.latestAnswer() * int256(10_000 - DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS - 1) / 10_000
        );

        // check cannot swap baseToken to accountingToken
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        uint256 previewOutputAmount = pool.previewSwap(address(baseToken), inputAmount);
        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), inputAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: inputAmount,
            minOutputAmount: previewOutputAmount
        });
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.MaxValueLossExceeded.selector);
        caliber.swap(order);

        // turn on recovery mode
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        // check cannot swap baseToken to accountingToken
        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.MaxValueLossExceeded.selector);
        caliber.swap(order);
    }

    function test_cannotHarvestWithInvalidInstruction() public {
        // instruction is not a harvest instruction
        Caliber.Instruction memory instruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        ISwapper.SwapOrder[] memory swapOrders = new ISwapper.SwapOrder[](0);
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.harvest(instruction, swapOrders);
    }

    function test_cannotHarvestWithInvalidProof() public {
        uint256 harvestAmount = 1e18;
        Caliber.Instruction memory instruction;
        ISwapper.SwapOrder[] memory swapOrders;

        // use wrong reward contract
        instruction = _buildMockRewardTokenHarvestInstruction(address(caliber), address(accountingToken), harvestAmount);
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);

        // use wrong commands
        instruction = _buildMockRewardTokenHarvestInstruction(address(caliber), address(accountingToken), harvestAmount);
        delete instruction.commands[0];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);

        // use wrong state
        instruction = _buildMockRewardTokenHarvestInstruction(address(caliber), address(accountingToken), harvestAmount);
        delete instruction.state[0];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);

        // use wrong bitmap
        instruction = _buildMockRewardTokenHarvestInstruction(address(caliber), address(accountingToken), harvestAmount);
        instruction.stateBitmap = 0;
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);
    }

    function test_harvestWithoutSwap() public {
        uint256 harvestAmount = 1e18;
        Caliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapper.SwapOrder[] memory swapOrders = new ISwapper.SwapOrder[](0);

        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);
        assertEq(baseToken.balanceOf(address(caliber)), harvestAmount);
    }

    function test_cannotHarvestWithSwapIntoNonAccountingTokenWhileInRecoveryMode() public {
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        Caliber.Instruction memory instruction;
        ISwapper.SwapOrder[] memory orders;

        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        vm.prank(securityCouncil);
        caliber.harvest(instruction, orders);
    }

    function test_cannotHarvestWithSwapWithoutMechanicWhileNotInRecoveryMode() public {
        Caliber.Instruction memory instruction;
        ISwapper.SwapOrder[] memory orders;

        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.harvest(instruction, orders);

        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.harvest(instruction, orders);
    }

    function test_cannotHarvestWithSwapWithoutSCWhileInRecoveryMode() public {
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        Caliber.Instruction memory instruction;
        ISwapper.SwapOrder[] memory orders;

        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.harvest(instruction, orders);

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.harvest(instruction, orders);
    }

    function test_harvestWithSwap() public {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        uint256 harvestAmount = 1e18;

        uint256 previewOutputAmount1 = pool.previewSwap(address(baseToken), harvestAmount);
        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), harvestAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: harvestAmount,
            minOutputAmount: previewOutputAmount1
        });

        Caliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapper.SwapOrder[] memory swapOrders = new ISwapper.SwapOrder[](1);
        swapOrders[0] = order;

        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);
        assertEq(accountingToken.balanceOf(address(caliber)), previewOutputAmount1);
    }

    function test_harvestWithSwapWhileInRecoveryMode() public {
        // turn on recovery mode
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        uint256 harvestAmount = 1e18;

        uint256 previewOutputAmount1 = pool.previewSwap(address(baseToken), harvestAmount);
        ISwapper.SwapOrder memory order = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), harvestAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: harvestAmount,
            minOutputAmount: previewOutputAmount1
        });

        Caliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapper.SwapOrder[] memory swapOrders = new ISwapper.SwapOrder[](1);
        swapOrders[0] = order;

        vm.prank(securityCouncil);
        caliber.harvest(instruction, swapOrders);
        assertEq(accountingToken.balanceOf(address(caliber)), previewOutputAmount1);
    }

    function test_cannotHarvestWithSwapFromBTWithValueLossTooHigh() public {
        // add liquidity to mock pool
        uint256 amount1 = 1e30 * PRICE_B_A;
        uint256 amount2 = 1e30;
        _addLiquidityToMockPool(amount1, amount2);

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        // decrease accountingToken value
        aPriceFeed1.setLatestAnswer(
            aPriceFeed1.latestAnswer() * int256(10_000 - DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS - 1) / 10_000
        );

        // check cannot harvest and swap baseToken to accountingToken
        uint256 harvestAmount = 3e18;
        Caliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapper.SwapOrder[] memory swapOrders = new ISwapper.SwapOrder[](1);
        uint256 previewOutputAmount = pool.previewSwap(address(baseToken), harvestAmount);
        swapOrders[0] = ISwapper.SwapOrder({
            aggregator: ISwapper.DexAggregator.ZEROX,
            data: abi.encodeCall(MockPool.swap, (address(baseToken), harvestAmount)),
            inputToken: address(baseToken),
            outputToken: address(accountingToken),
            inputAmount: harvestAmount,
            minOutputAmount: previewOutputAmount
        });
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.MaxValueLossExceeded.selector);
        caliber.harvest(instruction, swapOrders);

        // turn on recovery mode
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        // check cannot swap baseToken to accountingToken
        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.MaxValueLossExceeded.selector);
        caliber.harvest(instruction, swapOrders);
    }

    function test_cannotHarvestWithWrongRoot() public {
        uint256 harvestAmount = 1e18;
        Caliber.Instruction memory instruction =
            _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        ISwapper.SwapOrder[] memory swapOrders = new ISwapper.SwapOrder[](0);

        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);

        // schedule root update with a wrong root
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(keccak256(abi.encodePacked("wrongRoot")));

        // instruction can still be executed while the update is pending
        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);

        skip(caliber.timelockDuration());

        // instruction cannot be executed after the update takes effect
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.harvest(instruction, swapOrders);

        // schedule root update with the correct root
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(_getAllowedInstrMerkleRoot());

        // instruction cannot be executed while the update is pending
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.harvest(instruction, swapOrders);

        skip(caliber.timelockDuration());

        // instruction can be executed after the update takes effect
        vm.prank(mechanic);
        caliber.harvest(instruction, swapOrders);
    }

    function test_harvestOperatorPermissions() public {
        Caliber.Instruction memory instruction;
        ISwapper.SwapOrder[] memory swapOrders;

        // security council cannot call swap while recovery mode is off
        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.harvest(instruction, swapOrders);

        uint256 harvestAmount = 1e18;
        instruction = _buildMockRewardTokenHarvestInstruction(address(caliber), address(baseToken), harvestAmount);
        swapOrders = new ISwapper.SwapOrder[](1);

        // mechanic cannot call harvest with swap into a non-base-token
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidOutputToken.selector);
        caliber.harvest(instruction, swapOrders);

        // turn on recovery mode
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        // check mechanic now cannot call harvest
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.harvest(instruction, swapOrders);

        // check security council cannot call harvest
        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.RecoveryMode.selector);
        caliber.harvest(instruction, swapOrders);
    }

    function test_cannotAccountForPositionWithInvalidAccounting() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // replace end flag with null value in accounting output state
        delete instructions[1].state[1];
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.accountForPosition(instructions[1]);
    }

    function test_cannotAccountForPositionWithNonExistingPosition() public {
        ICaliber.Instruction memory instruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.expectRevert(ICaliber.PositionDoesNotExist.selector);
        caliber.accountForPosition(instruction);
    }

    function test_cannotAccountForPositionWithInvalidInstruction() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vaultInstructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);

        // instruction is not an accounting instruction
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.accountForPosition(vaultInstructions[0]);

        // position is a base token position
        vaultInstructions[1].positionId = BASE_TOKEN_POS_ID;
        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        caliber.accountForPosition(vaultInstructions[1]);
    }

    function test_cannotAccountForPositionWithInvalidProof() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(baseToken), 0);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault2));
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instructions[1]);

        // use wrong affected tokens list
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[1].affectedTokens[0] = address(0);
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instructions[1]);

        // use wrong commands
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[1].commands[2] = instructions[1].commands[1];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instructions[1]);

        // use wrong state
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[1].state[2] = instructions[1].state[0];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instructions[1]);

        // use wrong bitmap
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[1].stateBitmap = 0;
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instructions[1]);
    }

    function test_accountForPosition_4626() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, inputAmount * PRICE_B_A);

        uint256 yield = 1e18;
        deal(address(baseToken), address(vault), inputAmount + yield, true);

        uint256 previewAssets = vault.previewRedeem(vault.balanceOf(address(caliber)));

        caliber.accountForPosition(instructions[1]);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, previewAssets * PRICE_B_A);
    }

    function test_cannotAccountForPositionWithBaseTokenPosition() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        ICaliber.Instruction memory instruction = ICaliber.Instruction(
            BASE_TOKEN_POS_ID,
            ICaliber.InstructionType.ACCOUNTING,
            new address[](0),
            new bytes32[](0),
            new bytes[](0),
            0,
            new bytes32[](0)
        );

        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        caliber.accountForPosition(instruction);
    }

    function test_cannotAccountForPositionWithWrongRoot() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // schedule root update with a wrong root
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(keccak256(abi.encodePacked("wrongRoot")));

        // accounting can still be executed while the update is pending
        caliber.accountForPosition(instructions[1]);

        skip(caliber.timelockDuration());

        // accounting cannot be executed after the update takes effect
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instructions[1]);

        // schedule root update with the correct root
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(_getAllowedInstrMerkleRoot());

        // accounting cannot be executed while the update is pending
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instructions[1]);

        skip(caliber.timelockDuration());

        // accounting can be executed after the update takes effect
        caliber.accountForPosition(instructions[1]);
    }

    function test_accountForPositionBatch() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, inputAmount * PRICE_B_A);

        uint256 yield = 1e18;
        deal(address(baseToken), address(vault), inputAmount + yield, true);

        uint256 previewAssets = vault.previewRedeem(vault.balanceOf(address(caliber)));

        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = instructions[1];

        caliber.accountForPositionBatch(accountingInstructions);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, previewAssets * PRICE_B_A);
    }

    function test_cannotAccountForPositionBatchWithInvalidInstruction() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vaultInstructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);

        // 1st instruction is not an accounting instruction
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.accountForPositionBatch(accountingInstructions);

        // 2nd instruction is not an accounting instruction
        accountingInstructions = new ICaliber.Instruction[](2);
        accountingInstructions[0] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        accountingInstructions[1] =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.accountForPositionBatch(accountingInstructions);

        // position is a base token position
        accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = _build4626AccountingInstruction(address(caliber), BASE_TOKEN_POS_ID, address(vault));
        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        caliber.accountForPositionBatch(accountingInstructions);
    }

    function test_updateAndReportCaliberAUM() public {
        vm.startPrank(dao);
        oracleRegistry.setFeedStaleThreshold(address(aPriceFeed1), 1 days);
        oracleRegistry.setFeedStaleThreshold(address(bPriceFeed1), 1 days);
        vm.stopPrank();

        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](0);

        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), 0);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);

        skip(1 hours);

        uint256 inputAmount = 3e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        // check that accounting token is correctly accounted for in AUM
        uint256 expectedCaliberAUM = inputAmount;
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), expectedCaliberAUM);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);

        skip(1 hours);

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount2 = 2e18;
        deal(address(baseToken), address(caliber), inputAmount2, true);

        // check that base token is correctly accounted for in AUM
        expectedCaliberAUM += inputAmount2 * PRICE_B_A;
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), expectedCaliberAUM);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);

        skip(1 hours);

        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount2);
        vaultInstructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);

        // check that AUM remains the same after depositing baseToken into vault
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), expectedCaliberAUM);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);

        skip(1 hours);

        uint256 yield = 1e18;
        deal(address(baseToken), address(vault), inputAmount2 + yield, true);

        // check that AUM reflects vault yield
        accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = vaultInstructions[1];
        expectedCaliberAUM = inputAmount + vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A;
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), expectedCaliberAUM);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);
    }

    function test_cannotUpdateAndReportCaliberAUMWithInvalidInstruction() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vaultInstructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);

        // 1st instruction is not an accounting instruction
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.updateAndReportCaliberAUM(accountingInstructions);

        // 2nd instruction is not an accounting instruction
        accountingInstructions = new ICaliber.Instruction[](2);
        accountingInstructions[0] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        accountingInstructions[1] =
            _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.updateAndReportCaliberAUM(accountingInstructions);

        // position is a base token position
        accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = _build4626AccountingInstruction(address(caliber), BASE_TOKEN_POS_ID, address(vault));
        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        caliber.updateAndReportCaliberAUM(accountingInstructions);
    }

    function test_cannotUpdateAndReportCaliberAUMWithStalePosition() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vaultInstructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);

        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](0);
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), inputAmount * PRICE_B_A);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);

        skip(DEFAULT_CALIBER_POS_STALE_THRESHOLD + 1);

        // check that AUM cannot be updated with stale position
        vm.expectRevert(abi.encodeWithSelector(ICaliber.PositionAccountingStale.selector, VAULT_POS_ID));
        caliber.updateAndReportCaliberAUM(accountingInstructions);

        // include accounting instruction and check that AUM can then be updated
        accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = vaultInstructions[1];
        caliber.updateAndReportCaliberAUM(accountingInstructions);
        assertEq(caliber.lastReportedAUM(), inputAmount * PRICE_B_A);
        assertEq(caliber.lastReportedAUMTime(), block.timestamp);
    }

    ///
    /// Helper functions
    ///

    function _addLiquidityToMockPool(uint256 _amount1, uint256 _amount2) internal {
        deal(address(accountingToken), address(this), _amount1, true);
        deal(address(baseToken), address(this), _amount2, true);
        accountingToken.approve(address(pool), _amount1);
        baseToken.approve(address(pool), _amount2);
        pool.addLiquidity(_amount1, _amount2);
    }

    function _build4626DepositInstruction(address _caliber, uint256 _posId, address _vault, uint256 _assets)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = IERC4626(_vault).asset();

        bytes32[] memory commands = new bytes32[](2);
        // "0x095ea7b3010001ffffffffff" + IERC4626(_vault).asset()
        commands[0] = WeirollPlanner.buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            IERC4626(_vault).asset()
        );
        // "0x6e553f65010102ffffffffff" + _vault
        commands[1] = WeirollPlanner.buildCommand(
            IERC4626.deposit.selector,
            0x01, // call
            0x0102ffffffff, // 2 inputs at indices 1 and 2 of state
            0xff, // ignore result
            _vault
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_vault);
        state[1] = abi.encode(_assets);
        state[2] = abi.encode(_caliber);

        bytes32[] memory merkleProof = _getDeposit4626InstrProof();

        uint128 stateBitmap = 0xa0000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _build4626RedeemInstruction(address _caliber, uint256 _posId, address _vault, uint256 _shares)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = IERC4626(_vault).asset();

        bytes32[] memory commands = new bytes32[](1);
        // "0xba08765201000102ffffffff" + _vault
        commands[0] = WeirollPlanner.buildCommand(
            IERC4626.redeem.selector,
            0x01, // call
            0x000102ffffff, // 3 inputs at indices 0, 1 and 2 of state
            0xff, // ignore result
            _vault
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_shares);
        state[1] = abi.encode(_caliber);
        state[2] = abi.encode(_caliber);

        uint128 stateBitmap = 0x60000000000000000000000000000000;

        bytes32[] memory merkleProof = _getRedeem4626InstrProof();

        return ICaliber.Instruction(
            _posId, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _build4626AccountingInstruction(address _caliber, uint256 _posId, address _vault)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = IERC4626(_vault).asset();

        bytes32[] memory commands = new bytes32[](3);
        // "0x38d52e0f02ffffffffffff00" + _vault
        commands[0] = WeirollPlanner.buildCommand(
            IERC4626.asset.selector,
            0x02, // static call
            0xffffffffffff, // no input
            0x00, // store fixed size result at index 0 of state
            _vault
        );
        // "0x70a082310202ffffffffff02" + _vault
        commands[1] = WeirollPlanner.buildCommand(
            IERC20.balanceOf.selector,
            0x02, // static call
            0x02ffffffffff, // 1 input at index 2 of state
            0x02, // store fixed size result at index 2 of state
            _vault
        );
        // "0x4cdad5060202ffffffffff00" + _vault
        commands[2] = WeirollPlanner.buildCommand(
            IERC4626.previewRedeem.selector,
            0x02, // static call
            0x02ffffffffff, // 1 input at index 2 of state
            0x00, // store fixed size result at index 0 of state
            _vault
        );

        bytes[] memory state = new bytes[](3);
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);
        state[2] = abi.encode(_caliber);

        uint128 stateBitmap = 0x20000000000000000000000000000000;

        bytes32[] memory merkleProof = _getAccounting4626InstrProof();

        return ICaliber.Instruction(
            _posId, ICaliber.InstructionType.ACCOUNTING, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _buildMockPoolAddLiquidityInstruction(uint256 _posId, address _pool, uint256 _assets0, uint256 _assets1)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](2);
        affectedTokens[0] = MockPool(_pool).token0();
        affectedTokens[1] = MockPool(_pool).token1();

        bytes32[] memory commands = new bytes32[](3);
        // "0x095ea7b3010001ffffffffff" + MockPool(_pool).token0()
        commands[0] = WeirollPlanner.buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            MockPool(_pool).token0()
        );
        // "0x095ea7b3010002ffffffffff" + MockPool(_pool).token1()
        commands[1] = WeirollPlanner.buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0002ffffffff, // 2 inputs at indices 0 and 2 of state
            0xff, // ignore result
            MockPool(_pool).token1()
        );
        // "0x9cd441da010102ffffffffff" + _pool
        commands[2] = WeirollPlanner.buildCommand(
            MockPool.addLiquidity.selector,
            0x01, // call
            0x0102ffffffff, // 2 inputs at indices 1 and 2 of state
            0xff, // ignore result
            _pool
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_pool);
        state[1] = abi.encode(_assets0);
        state[2] = abi.encode(_assets1);

        bytes32[] memory merkleProof = _getAddLiquidityMockPoolInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _buildMockPoolAddLiquidityOneSide0Instruction(uint256 _posId, address _pool, uint256 _assets0)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address token0 = MockPool(_pool).token0();

        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = token0;

        bytes32[] memory commands = new bytes32[](2);
        // "0x095ea7b3010001ffffffffff" + token0
        commands[0] = WeirollPlanner.buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            token0
        );
        // "0x8e022364010102ffffffffff" + _pool
        commands[1] = WeirollPlanner.buildCommand(
            MockPool.addLiquidityOneSide.selector,
            0x01, // call
            0x0102ffffffff, // 2 inputs at indices 1 and 2 of state
            0xff, // ignore result
            _pool
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_pool);
        state[1] = abi.encode(_assets0);
        state[2] = abi.encode(token0);

        bytes32[] memory merkleProof = _getAddLiquidityOneSide0MockPoolInstrProof();

        uint128 stateBitmap = 0xa0000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _buildMockPoolRemoveLiquidityOneSide1Instruction(uint256 _posId, address _pool, uint256 _lpTokens)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address token1 = MockPool(_pool).token1();
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = token1;

        bytes32[] memory commands = new bytes32[](1);
        // "0xdf7aebb9010001ffffffffff" + _pool
        commands[0] = WeirollPlanner.buildCommand(
            MockPool.removeLiquidityOneSide.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            _pool
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_lpTokens);
        state[1] = abi.encode(token1);

        bytes32[] memory merkleProof = _getRemoveLiquidityOneSide1MockPoolInstrProof();

        uint128 stateBitmap = 0x40000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    /// @dev Builds a mock pool accounting instruction for removing liquidity one-sided from a pool (only token1)
    function _buildMockPoolAccountingInstruction(address _caliber, uint256 _posId, address _pool)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockPool(_pool).token1();

        bytes32[] memory commands = new bytes32[](2);
        // "0x70a082310202ffffffffff02" + _pool
        commands[0] = WeirollPlanner.buildCommand(
            IERC20.balanceOf.selector,
            0x02, // static call
            0x02ffffffffff, // 1 input at index 2 of state
            0x02, // store fixed size result at index 2 of state
            _pool
        );
        // "0xeeb47144020200ffffffff00" + _pool
        commands[1] = WeirollPlanner.buildCommand(
            MockPool.previewRemoveLiquidityOneSide.selector,
            0x02, // call
            0x0200ffffffff, // 2 inputs at indices 2 and 0 of state
            0x00, // store fixed size result at index 0 of state
            _pool
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(MockPool(_pool).token1());
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);
        state[2] = abi.encode(_caliber);

        bytes32[] memory merkleProof = _getAccountingMockPoolInstrProof();

        uint128 stateBitmap = 0xa0000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, ICaliber.InstructionType.ACCOUNTING, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _buildMockRewardTokenHarvestInstruction(address _caliber, address _mockRewardToken, uint256 _harvestAmount)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        bytes32[] memory commands = new bytes32[](1);
        // "0x40c10f19010001ffffffffff" + _mockRewardToken
        commands[0] = WeirollPlanner.buildCommand(
            MockERC20.mint.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            _mockRewardToken
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_caliber);
        state[1] = abi.encode(_harvestAmount);

        bytes32[] memory merkleProof = _getHarvestMockBaseTokenInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return ICaliber.Instruction(
            0, ICaliber.InstructionType.HARVEST, new address[](0), commands, state, stateBitmap, merkleProof
        );
    }
}
