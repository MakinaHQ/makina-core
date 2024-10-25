// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./BaseTest.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ICaliber} from "../src/interfaces/ICaliber.sol";
import {IOracleRegistry} from "../src/interfaces/IOracleRegistry.sol";
import {WeirollPlanner} from "./utils/WeirollPlanner.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC4626} from "./mocks/MockERC4626.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract CaliberTest is BaseTest {
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event SecurityCouncilChanged(address indexed oldSecurityCouncil, address indexed newecurityCouncil);
    event RecoveryModeChanged(bool indexed enabled);
    event PositionCreated(uint256 indexed id);
    event PositionClosed(uint256 indexed id);

    MockERC20 private baseToken;

    MockPriceFeed private b1PriceFeed1;
    MockPriceFeed private aPriceFeed1;

    /// @dev A is the accounting token, B is the base token
    /// and E is the reference currency of the oracle registry
    uint256 private constant PRICE_A_E = 150;
    uint256 private constant PRICE_B_E = 60000;
    uint256 private constant PRICE_B_A = 400;

    bytes32 private constant ACCOUNTING_OUTPUT_STATE_END_OF_ARGS = bytes32(type(uint256).max);

    function _setUp() public override {
        baseToken = new MockERC20("Base Token", "BT", 18);

        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);
        b1PriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_E * 1e18), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(b1PriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        caliber = _deployCaliber(address(accountingToken), accountingTokenPosID);
    }

    function test_caliber_getters() public view {
        assertEq(caliber.hubMachine(), address(0));
        assertEq(caliber.mechanic(), mechanic);
        assertEq(caliber.oracleRegistry(), address(oracleRegistry));
        assertEq(caliber.accountingToken(), address(accountingToken));
        assertEq(caliber.recoveryMode(), false);
        assertEq(caliber.isBaseToken(address(accountingToken)), true);
        assertEq(caliber.getPositionsLength(), 1);
    }

    function test_cannotAddBaseTokenWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.addBaseToken(address(baseToken), 2);
    }

    function test_addBaseToken() public {
        uint256 posId = 2;

        vm.expectEmit(true, true, false, true, address(caliber));
        emit PositionCreated(posId);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), posId);

        assertEq(caliber.isBaseToken(address(baseToken)), true);
        assertEq(caliber.getPositionsLength(), 2);
        assertEq(caliber.getPositionId(1), posId);
        assertEq(caliber.getPosition(posId).lastAccountingTime, 0);
        assertEq(caliber.getPosition(posId).value, 0);
        assertEq(caliber.getPosition(posId).isBaseToken, true);
    }

    function test_cannotAddBaseTokenWithSamePosIdTwice() public {
        vm.startPrank(dao);

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken), 1);

        caliber.addBaseToken(address(baseToken), 2);

        MockERC20 baseToken2 = new MockERC20("Base Token 2", "BT2", 18);
        oracleRegistry.setTokenFeedData(
            address(baseToken2), address(b1PriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        vm.expectRevert(ICaliber.PositionAlreadyExists.selector);
        caliber.addBaseToken(address(baseToken2), 2);
    }

    function test_cannotAddSameBaseTokenTwice() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        vm.expectRevert(ICaliber.BaseTokenAlreadyExists.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 3);
    }

    function test_cannotAddBaseTokenWithZeroId() public {
        vm.expectRevert(ICaliber.ZeroPositionID.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 0);
    }

    function test_cannotAddBaseTokenWithoutRegisteredFeed() public {
        MockERC20 baseToken2;
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken2), 3);
    }

    function test_cannotSetPositionAsBaseTokenWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setPositionAsBaseToken(2, address(baseToken));
    }

    function test_cannotSetPositionAsBaseTokenWithoutExistingPosition() public {
        vm.expectRevert(ICaliber.PositionDoesNotExist.selector);
        vm.prank(dao);
        caliber.setPositionAsBaseToken(2, address(baseToken));
    }

    function test_cannotSetPositionAsBaseTokenWithAlreadyBaseTokenPosition() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC20 baseToken2 = new MockERC20("Base Token 2", "BT2", 18);

        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        vm.prank(dao);
        caliber.setPositionAsBaseToken(2, address(baseToken2));
    }

    function test_cannotSetPositionAsBaseTokenWithExistingBaseToken() public {
        vm.startPrank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);
        oracleRegistry.setTokenFeedData(address(vault), address(b1PriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        caliber.addBaseToken(address(vault), 3);
        vm.stopPrank();

        uint256 posId = 4;
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

        // create a new position
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        vm.expectRevert(ICaliber.BaseTokenAlreadyExists.selector);
        vm.prank(dao);
        caliber.setPositionAsBaseToken(posId, address(baseToken));
    }

    function test_setPositionAsBaseToken() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

        // create a new position
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertFalse(caliber.isBaseToken(address(vault)));
        assertEq(caliber.getPositionsLength(), 3);

        vm.prank(dao);
        caliber.setPositionAsBaseToken(posId, address(vault));

        assertTrue(caliber.isBaseToken(address(vault)));
        assertEq(caliber.getPositionsLength(), 3);
    }

    function test_cannotSetPositionAsNonBaseTokenWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setPositionAsNonBaseToken(2);
    }

    function test_cannotSetPositionAsNonBaseTokenIfAlreadyNonBaseToken() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        deal(address(baseToken), address(caliber), 3e18, true);

        vm.startPrank(dao);
        caliber.setPositionAsNonBaseToken(2);
        vm.expectRevert(ICaliber.NotBaseTokenPosition.selector);
        caliber.setPositionAsNonBaseToken(2);
    }

    function test_cannotSetPositionAsNonBaseTokenWithoutExistingPosition() public {
        vm.expectRevert(ICaliber.PositionDoesNotExist.selector);
        vm.prank(dao);
        caliber.setPositionAsNonBaseToken(2);
    }

    function test_setPositionAsNonBaseTokenEmpty() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        assertTrue(caliber.isBaseToken(address(baseToken)));
        assertEq(caliber.getPositionsLength(), 2);

        vm.prank(dao);
        caliber.setPositionAsNonBaseToken(2);

        // the position should be closed
        assertFalse(caliber.isBaseToken(address(baseToken)));
        assertEq(caliber.getPositionsLength(), 1);
    }

    function test_setPositionAsNonBaseTokenNonEmpty() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        deal(address(baseToken), address(caliber), 1e18, true);

        assertTrue(caliber.isBaseToken(address(baseToken)));
        assertEq(caliber.getPositionsLength(), 2);

        vm.prank(dao);
        caliber.setPositionAsNonBaseToken(2);

        // the position should still be there
        assertFalse(caliber.isBaseToken(address(baseToken)));
        assertEq(caliber.getPositionsLength(), 2);
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
        caliber.addBaseToken(address(baseToken), 2);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, 0);

        (uint256 value, int256 change) = caliber.accountForBaseToken(2);

        assertEq(value, 0);
        assertEq(change, 0);
        assertEq(caliber.getPosition(2).value, value);
        assertEq(caliber.getPosition(2).lastAccountingTime, block.timestamp);

        deal(address(baseToken), address(caliber), 1e18, true);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, block.timestamp);

        (value, change) = caliber.accountForBaseToken(2);

        assertEq(value, 1e18 * PRICE_B_A);
        assertEq(change, int256(1e18 * PRICE_B_A));
        assertEq(caliber.getPosition(2).value, value);
        assertEq(caliber.getPosition(2).lastAccountingTime, block.timestamp);

        uint256 newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        deal(address(baseToken), address(caliber), 3e18, true);
        // this should not affect the accounting
        deal(address(accountingToken), address(caliber), 10e18, true);

        (value, change) = caliber.accountForBaseToken(2);

        assertEq(value, 3e18 * PRICE_B_A);
        assertEq(change, int256(2e18 * PRICE_B_A));
        assertEq(caliber.getPosition(2).value, value);
        assertEq(caliber.getPosition(2).lastAccountingTime, newTimestamp);

        newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        deal(address(baseToken), address(caliber), 2e18, true);

        (value, change) = caliber.accountForBaseToken(2);

        assertEq(value, 2e18 * PRICE_B_A);
        assertEq(change, -1 * int256(1e18 * PRICE_B_A));
        assertEq(caliber.getPosition(2).value, value);
        assertEq(caliber.getPosition(2).lastAccountingTime, newTimestamp);
    }

    function test_cannotAccountForUnexistingBTPosition() public {
        vm.prank(dao);

        vm.expectRevert(ICaliber.NotBaseTokenPosition.selector);
        caliber.accountForBaseToken(2);
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

    function test_cannotCallManagePositionWithoutInstruction() public {
        vm.expectRevert(ICaliber.InvalidInstruction.selector);
        vm.prank(mechanic);
        caliber.managePosition(new ICaliber.Instruction[](0));
    }

    function test_cannotCallManageNonBaseTokenPositionWithInvalidInstruction() public {
        uint256 posId = 3;
        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](1);

        vm.startPrank(mechanic);

        // empty instruction
        vm.expectRevert(ICaliber.InvalidInstruction.selector);
        caliber.managePosition(instructions);

        instructions[0] = ICaliber.Instruction(
            posId, ICaliber.InstructionType.ACCOUNTING, new bytes32[](0), new bytes[](0), 0, new bytes32[](0)
        );

        // first instruction is not a manage instruction
        vm.expectRevert(ICaliber.InvalidInstruction.selector);
        caliber.managePosition(instructions);

        instructions[0] = ICaliber.Instruction(
            posId, ICaliber.InstructionType.MANAGE, new bytes32[](0), new bytes[](0), 0, new bytes32[](0)
        );

        // missing second instruction
        vm.expectRevert(ICaliber.InvalidInstruction.selector);
        caliber.managePosition(instructions);

        instructions = new ICaliber.Instruction[](2);
        instructions[0] = ICaliber.Instruction(
            posId, ICaliber.InstructionType.MANAGE, new bytes32[](0), new bytes[](0), 0, new bytes32[](0)
        );
        instructions[1] = ICaliber.Instruction(
            posId, ICaliber.InstructionType.MANAGE, new bytes32[](0), new bytes[](0), 0, new bytes32[](0)
        );

        // second instruction is not an accounting instruction
        vm.expectRevert(ICaliber.InvalidInstruction.selector);
        caliber.managePosition(instructions);

        instructions = new ICaliber.Instruction[](2);
        instructions[0] = ICaliber.Instruction(
            posId, ICaliber.InstructionType.MANAGE, new bytes32[](0), new bytes[](0), 0, new bytes32[](0)
        );
        instructions[1] = ICaliber.Instruction(
            posId + 1, ICaliber.InstructionType.ACCOUNTING, new bytes32[](0), new bytes[](0), 0, new bytes32[](0)
        );

        // instructions have different positionId
        vm.expectRevert(ICaliber.InvalidInstruction.selector);
        caliber.managePosition(instructions);

        instructions = new ICaliber.Instruction[](3);
        instructions[0] = ICaliber.Instruction(
            posId, ICaliber.InstructionType.MANAGE, new bytes32[](0), new bytes[](0), 0, new bytes32[](0)
        );
        instructions[1] = ICaliber.Instruction(
            posId, ICaliber.InstructionType.ACCOUNTING, new bytes32[](0), new bytes[](0), 0, new bytes32[](0)
        );

        // more than 2 instructions
        vm.expectRevert(ICaliber.InvalidInstruction.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotCallManageBaseTokenPositionWithInvalidInstruction() public {
        uint256 posId = 2;

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), posId);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](1);

        vm.startPrank(mechanic);

        // empty instruction
        vm.expectRevert(ICaliber.InvalidInstruction.selector);
        caliber.managePosition(instructions);

        // first instruction is not a manage instruction
        instructions[0] = ICaliber.Instruction(
            posId, ICaliber.InstructionType.ACCOUNTING, new bytes32[](0), new bytes[](0), 0, new bytes32[](0)
        );
        vm.expectRevert(ICaliber.InvalidInstruction.selector);
        caliber.managePosition(instructions);

        // more than 1 instruction
        instructions = new ICaliber.Instruction[](2);
        instructions[0] = ICaliber.Instruction(
            posId, ICaliber.InstructionType.MANAGE, new bytes32[](0), new bytes[](0), 0, new bytes32[](0)
        );
        vm.expectRevert(ICaliber.InvalidInstruction.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotCallManagePositionWithInvalidAccounting() public {
        // baseToken is not set as an actual base token in the caliber
        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.managePosition(instructions);

        // set baseToken as an actual base token
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        // replace end flag with null value in accounting output state with odd length
        delete instructions[1].state[2];
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.managePosition(instructions);

        // put an end flag in the state after unequal number of assets and amounts
        bytes32[] memory commands = new bytes32[](1);
        commands[0] = WeirollPlanner.buildCommand(
            IERC4626.asset.selector,
            0x02, // static call
            0xffffffffffff, // no input
            0x00, // store fixed size result at index 0 of state
            address(vault)
        );
        bytes[] memory state = new bytes[](2);
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);
        instructions[1].commands = commands;
        instructions[1].state = state;

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.managePosition(instructions);
    }

    function test_managePosition_4626_create() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

        assertEq(caliber.getPositionsLength(), 2);

        vm.expectEmit(true, true, false, true, address(caliber));
        emit PositionCreated(posId);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(posId).value, inputAmount * PRICE_B_A);
    }

    function test_managePosition_4626_increase() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

        assertEq(caliber.getPositionsLength(), 2);

        vm.startPrank(mechanic);
        caliber.managePosition(instructions);
        previewShares += vault.previewDeposit(inputAmount);
        caliber.managePosition(instructions);
        vm.stopPrank();

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(posId).value, 2 * inputAmount * PRICE_B_A);
    }

    function test_managePosition_4626_decrease() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

        assertEq(caliber.getPositionsLength(), 2);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        uint256 sharesToRedeem = vault.balanceOf(address(caliber)) / 2;

        instructions[0] = _build4626RedeemInstruction(address(caliber), posId, address(vault), sharesToRedeem);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares - sharesToRedeem);
        assertEq(caliber.getPosition(posId).value, vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A);
    }

    function test_managePosition_4626_close() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

        assertEq(caliber.getPositionsLength(), 2);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        instructions[0] =
            _build4626RedeemInstruction(address(caliber), posId, address(vault), vault.balanceOf(address(caliber)));

        vm.expectEmit(true, true, false, true, address(caliber));
        emit PositionClosed(posId);
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 2);
        assertEq(vault.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(posId).value, 0);
    }

    function test_managePosition_baseToken_4626_increase() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        // set up feed data for the vault, considering 1:1 ratio with its underlying, and add vault as a base token
        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(vault), address(b1PriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        caliber.addBaseToken(address(vault), posId);
        vm.stopPrank();

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](1);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);

        assertEq(caliber.getPositionsLength(), 3);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(posId).value, inputAmount * PRICE_B_A);

        previewShares += vault.previewDeposit(inputAmount);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(posId).value, 2 * inputAmount * PRICE_B_A);
    }

    function test_managePosition_baseToken_4626_decrease() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        // set up feed data for the vault, considering 1:1 ratio with its underlying, and add vault as a base token
        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(vault), address(b1PriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        caliber.addBaseToken(address(vault), posId);
        vm.stopPrank();

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](1);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);

        assertEq(caliber.getPositionsLength(), 3);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        uint256 sharesToRedeem = vault.balanceOf(address(caliber)) / 2;

        instructions[0] = _build4626RedeemInstruction(address(caliber), posId, address(vault), sharesToRedeem);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares - sharesToRedeem);
        assertEq(caliber.getPosition(posId).value, vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A);
    }

    function test_managePosition_baseToken_4626_full_decrease() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;

        // set up feed data for the vault, considering 1:1 ratio with its underlying, and add vault as a base token
        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(vault), address(b1PriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        caliber.addBaseToken(address(vault), posId);
        vm.stopPrank();

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](1);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);

        assertEq(caliber.getPositionsLength(), 3);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        instructions[0] =
            _build4626RedeemInstruction(address(caliber), posId, address(vault), vault.balanceOf(address(caliber)));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(posId).value, 0);
    }

    function test_managePositionOperatorPermissions() public {
        // security council cannot call managePosition while recovery mode is off
        ICaliber.Instruction[] memory dummyInstructions;
        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.managePosition(dummyInstructions);

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        Caliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

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
        assertEq(caliber.getPosition(posId).value, inputAmount * PRICE_B_A);

        // check security council can decrease position
        uint256 sharesToRedeem = vault.balanceOf(address(caliber)) / 2;
        vm.prank(securityCouncil);
        instructions[0] = _build4626RedeemInstruction(address(caliber), posId, address(vault), sharesToRedeem);
        caliber.managePosition(instructions);
        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares - sharesToRedeem);
        assertEq(caliber.getPosition(posId).value, vault.previewRedeem(vault.balanceOf(address(caliber))) * PRICE_B_A);

        // check that security council can close position
        instructions[0] =
            _build4626RedeemInstruction(address(caliber), posId, address(vault), vault.balanceOf(address(caliber)));
        vm.prank(securityCouncil);
        caliber.managePosition(instructions);
        assertEq(caliber.getPositionsLength(), 2);
        assertEq(vault.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(posId).value, 0);
    }

    function test_CannotAccountForPositionWithoutExistingPosition() public {
        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);
        ICaliber.Instruction memory instruction = _build4626AccountingInstruction(address(caliber), 3, address(vault));

        vm.expectRevert(ICaliber.PositionDoesNotExist.selector);
        caliber.accountForPosition(instruction);
    }

    function test_cannotCallAccountForPositionWithInvalidAccounting() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        // set baseToken position as non-base-token
        vm.prank(dao);
        caliber.setPositionAsNonBaseToken(2);

        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.accountForPosition(instructions[1]);

        // set baseToken back as a base token
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        // replace end flag with null value in accounting output state with odd length
        delete instructions[1].state[2];
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.accountForPosition(instructions[1]);

        // put an end flag in the state after unequal number of assets and amounts
        bytes32[] memory commands = new bytes32[](1);
        commands[0] = WeirollPlanner.buildCommand(
            IERC4626.asset.selector,
            0x02, // static call
            0xffffffffffff, // no input
            0x00, // store fixed size result at index 0 of state
            address(vault)
        );
        bytes[] memory state = new bytes[](2);
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);
        instructions[1].commands = commands;
        instructions[1].state = state;

        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.accountForPosition(instructions[1]);
    }

    function test_CannotAccountForPositionWithNonAccountingPosition() public {
        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);
        ICaliber.Instruction memory instruction = _build4626AccountingInstruction(address(caliber), 3, address(vault));

        vm.expectRevert(ICaliber.PositionDoesNotExist.selector);
        caliber.accountForPosition(instruction);
    }

    function test_accountForPosition_4626() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(posId).value, inputAmount * PRICE_B_A);

        uint256 yield = 1e18;
        deal(address(baseToken), address(vault), inputAmount + yield, true);

        uint256 previewAssets = vault.previewRedeem(vault.balanceOf(address(caliber)));

        caliber.accountForPosition(instructions[1]);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(posId).value, previewAssets * PRICE_B_A);
    }

    function test_cannotAccountForPositionWithBaseTokenPosition() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        MockERC4626 vault = new MockERC4626("Test Vault", "TV", IERC20(baseToken), 0);

        uint256 posId = 3;
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), posId, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), posId, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        vm.prank(dao);
        caliber.setPositionAsBaseToken(posId, address(vault));

        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        caliber.accountForPosition(instructions[1]);
    }

    ///
    /// Helper functions
    ///

    function _build4626DepositInstruction(address caliber, uint256 posId, address vault, uint256 assets)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        bytes32[] memory commands = new bytes32[](2);
        commands[0] = WeirollPlanner.buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            IERC4626(vault).asset()
        );
        commands[1] = WeirollPlanner.buildCommand(
            IERC4626.deposit.selector,
            0x01, // call
            0x0102ffffffff, // 2 inputs at indices 1 and 2 of state
            0xff, // ignore result
            vault
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(vault);
        state[1] = abi.encode(assets);
        state[2] = abi.encode(caliber);

        return ICaliber.Instruction(posId, ICaliber.InstructionType.MANAGE, commands, state, 0, new bytes32[](0));
    }

    function _build4626RedeemInstruction(address caliber, uint256 posId, address vault, uint256 shares)
        internal
        pure
        returns (ICaliber.Instruction memory)
    {
        bytes32[] memory commands = new bytes32[](1);
        commands[0] = WeirollPlanner.buildCommand(
            IERC4626.redeem.selector,
            0x01, // call
            0x000102ffffff, // 3 inputs at indices 0, 1 and 2 of state
            0xff, // ignore result
            vault
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(shares);
        state[1] = abi.encode(caliber);
        state[2] = abi.encode(caliber);

        return ICaliber.Instruction(posId, ICaliber.InstructionType.MANAGE, commands, state, 0, new bytes32[](0));
    }

    function _build4626AccountingInstruction(address caliber, uint256 posId, address vault)
        internal
        pure
        returns (ICaliber.Instruction memory)
    {
        bytes32[] memory commands = new bytes32[](3);
        commands[0] = WeirollPlanner.buildCommand(
            IERC4626.asset.selector,
            0x02, // static call
            0xffffffffffff, // no input
            0x00, // store fixed size result at index 0 of state
            vault
        );
        commands[1] = WeirollPlanner.buildCommand(
            IERC20.balanceOf.selector,
            0x02, // static call
            0x01ffffffffff, // 1 input at index 1 of state
            0x01, // store fixed size result at index 1 of state
            vault
        );
        commands[2] = WeirollPlanner.buildCommand(
            IERC4626.previewRedeem.selector,
            0x02, // static call
            0x01ffffffffff, // 1 input at index 1 of state
            0x01, // store fixed size result at index 1 of state
            vault
        );

        bytes[] memory state = new bytes[](3);
        state[1] = abi.encode(caliber);
        state[2] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);

        return ICaliber.Instruction(posId, ICaliber.InstructionType.ACCOUNTING, commands, state, 0, new bytes32[](0));
    }
}
