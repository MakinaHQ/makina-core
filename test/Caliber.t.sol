// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./BaseTest.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ICaliber} from "../src/interfaces/ICaliber.sol";
import {IOracleRegistry} from "../src/interfaces/IOracleRegistry.sol";
import {WeirollPlanner} from "./utils/WeirollPlanner.sol";
import {MockERC4626} from "./mocks/MockERC4626.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract CaliberTest is BaseTest {
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event SecurityCouncilChanged(address indexed oldSecurityCouncil, address indexed newecurityCouncil);
    event RecoveryModeChanged(bool indexed enabled);
    event PositionCreated(uint256 indexed id);
    event PositionClosed(uint256 indexed id);
    event AllowedScriptsRootUpdated(bytes32 indexed newMerkleRoot);

    bytes32 private constant ACCOUNTING_OUTPUT_STATE_END_OF_ARGS = bytes32(type(uint256).max);

    /// @dev A is the accounting token, B is the base token
    /// and E is the reference currency of the oracle registry
    uint256 private constant PRICE_A_E = 150;
    uint256 private constant PRICE_B_E = 60000;
    uint256 private constant PRICE_B_A = 400;

    uint256 private constant BASE_TOKEN_POS_ID = 2;
    uint256 private constant VAULT_POS_ID = 3;

    MockERC20 private baseToken;
    MockERC4626 private vault;

    MockPriceFeed private bPriceFeed1;
    MockPriceFeed private aPriceFeed1;

    function _setUp() public override {
        baseToken = new MockERC20("baseToken", "BT", 18);
        vault = new MockERC4626("vault", "VLT", IERC20(baseToken), 0);

        aPriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_E * 1e18), block.timestamp);
        bPriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_E * 1e18), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        caliber = _deployCaliber(address(accountingToken), accountingTokenPosID, bytes32(""));

        // generate merkle tree for scripts involving mock base token and vault
        _generateMerkleData(address(caliber), address(baseToken), address(vault), VAULT_POS_ID);
        vm.prank(dao);
        caliber.setAllowedScriptsRoot(_getAllowedScriptsMerkleRoot());
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
        caliber.addBaseToken(address(baseToken), accountingTokenPosID);

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
        vm.expectRevert(ICaliber.ZeroPositionID.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 0);
    }

    function test_cannotAddBaseTokenWithoutRegisteredFeed() public {
        MockERC20 baseToken2;
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken2), BASE_TOKEN_POS_ID + 1);
    }

    function test_cannotSetPositionAsBaseTokenWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setPositionAsBaseToken(BASE_TOKEN_POS_ID, address(baseToken));
    }

    function test_cannotSetPositionAsBaseTokenWithoutExistingPosition() public {
        vm.expectRevert(ICaliber.PositionDoesNotExist.selector);
        vm.prank(dao);
        caliber.setPositionAsBaseToken(BASE_TOKEN_POS_ID, address(baseToken));
    }

    function test_cannotSetPositionAsBaseTokenWithAlreadyBaseTokenPosition() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        MockERC20 baseToken2 = new MockERC20("Base Token 2", "BT2", 18);

        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        vm.prank(dao);
        caliber.setPositionAsBaseToken(BASE_TOKEN_POS_ID, address(baseToken2));
    }

    function test_cannotSetPositionAsBaseTokenWithExistingBaseToken() public {
        vm.startPrank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        oracleRegistry.setTokenFeedData(address(vault), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        caliber.addBaseToken(address(vault), 4);
        vm.stopPrank();

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create a new position
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        vm.expectRevert(ICaliber.BaseTokenAlreadyExists.selector);
        vm.prank(dao);
        caliber.setPositionAsBaseToken(VAULT_POS_ID, address(baseToken));
    }

    function test_setPositionAsBaseToken() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        // create a new position
        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertFalse(caliber.isBaseToken(address(vault)));
        assertEq(caliber.getPositionsLength(), 3);

        vm.prank(dao);
        caliber.setPositionAsBaseToken(VAULT_POS_ID, address(vault));

        assertTrue(caliber.isBaseToken(address(vault)));
        assertEq(caliber.getPositionsLength(), 3);
    }

    function test_cannotSetPositionAsNonBaseTokenWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setPositionAsNonBaseToken(BASE_TOKEN_POS_ID);
    }

    function test_cannotSetPositionAsNonBaseTokenIfAlreadyNonBaseToken() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        deal(address(baseToken), address(caliber), 3e18, true);

        vm.startPrank(dao);
        caliber.setPositionAsNonBaseToken(BASE_TOKEN_POS_ID);
        vm.expectRevert(ICaliber.NotBaseTokenPosition.selector);
        caliber.setPositionAsNonBaseToken(BASE_TOKEN_POS_ID);
    }

    function test_cannotSetPositionAsNonBaseTokenWithoutExistingPosition() public {
        vm.expectRevert(ICaliber.PositionDoesNotExist.selector);
        vm.prank(dao);
        caliber.setPositionAsNonBaseToken(BASE_TOKEN_POS_ID);
    }

    function test_setPositionAsNonBaseTokenEmpty() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        assertTrue(caliber.isBaseToken(address(baseToken)));
        assertEq(caliber.getPositionsLength(), 2);

        vm.prank(dao);
        caliber.setPositionAsNonBaseToken(BASE_TOKEN_POS_ID);

        // the position should be closed
        assertFalse(caliber.isBaseToken(address(baseToken)));
        assertEq(caliber.getPositionsLength(), 1);
    }

    function test_setPositionAsNonBaseTokenNonEmpty() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        deal(address(baseToken), address(caliber), 1e18, true);

        assertTrue(caliber.isBaseToken(address(baseToken)));
        assertEq(caliber.getPositionsLength(), 2);

        vm.prank(dao);
        caliber.setPositionAsNonBaseToken(BASE_TOKEN_POS_ID);

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

    function test_cannotSetAllowedScriptRootWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliber.setAllowedScriptsRoot(bytes32(""));
    }

    function test_setAllowedScriptRoot() public {
        bytes32 newRoot = keccak256(abi.encodePacked("newRoot"));
        vm.expectEmit(true, true, false, true, address(caliber));
        emit AllowedScriptsRootUpdated(newRoot);
        vm.prank(dao);
        caliber.setAllowedScriptsRoot(newRoot);
        assertEq(caliber.allowedScriptsRoot(), newRoot);
    }

    function test_cannotCallManagePositionWithoutInstruction() public {
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        vm.prank(mechanic);
        caliber.managePosition(new ICaliber.Instruction[](0));
    }

    function test_cannotCallManageNonBaseTokenPositionWithInvalidInstruction() public {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        vm.startPrank(mechanic);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](1);

        // first instruction is not a manage instruction
        instructions[0] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.managePosition(instructions);

        // missing second instruction
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        caliber.managePosition(instructions);

        // second instruction is not an accounting instruction
        instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = instructions[0];
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.managePosition(instructions);

        // instructions have different positionId
        instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID + 1, address(vault));
        vm.expectRevert(ICaliber.UnmatchingInstructions.selector);
        caliber.managePosition(instructions);

        // more than 2 instructions
        instructions = new ICaliber.Instruction[](3);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[2] = instructions[1];
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotCallManageBaseTokenPositionWithInvalidInstruction() public {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        // set up feed data for the vault, considering 1:1 ratio with its underlying, and add vault as a base token
        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(vault), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        caliber.addBaseToken(address(vault), VAULT_POS_ID);
        vm.stopPrank();

        vm.startPrank(mechanic);

        // first instruction is not a manage instruction
        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](1);
        instructions[0] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.managePosition(instructions);

        // more than 1 instruction
        instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.expectRevert(ICaliber.InvalidInstructionsLength.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotCallManagePositionWithInvalidAccounting() public {
        // baseToken is not set as an actual base token in the caliber

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.managePosition(instructions);

        // set baseToken as an actual base token
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        // replace end flag with null value in accounting output state with odd length
        delete instructions[1].state[2];
        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.managePosition(instructions);

        // put an end flag in the state after unequal number of assets and amounts
        bytes[] memory badState = new bytes[](4);
        badState[0] = instructions[1].state[0];
        badState[1] = instructions[1].state[1];
        badState[2] = abi.encode(address(1));
        badState[3] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);
        instructions[1].state = badState;

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.managePosition(instructions);
    }

    function test_cannotCallManagePositionWithInvalidProof() public {
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
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID + 1, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID + 1, address(vault));
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

    function test_managePosition_baseToken_4626_increase() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        // set up feed data for the vault, considering 1:1 ratio with its underlying, and add vault as a base token
        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(vault), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        caliber.addBaseToken(address(vault), VAULT_POS_ID);
        vm.stopPrank();

        deal(address(baseToken), address(caliber), 2 * inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](1);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);

        assertEq(caliber.getPositionsLength(), 3);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, inputAmount * PRICE_B_A);

        previewShares += vault.previewDeposit(inputAmount);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, 2 * inputAmount * PRICE_B_A);
    }

    function test_managePosition_baseToken_4626_decrease() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;
        uint256 previewShares = vault.previewDeposit(inputAmount);

        // set up feed data for the vault, considering 1:1 ratio with its underlying, and add vault as a base token
        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(vault), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        caliber.addBaseToken(address(vault), VAULT_POS_ID);
        vm.stopPrank();

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](1);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);

        assertEq(caliber.getPositionsLength(), 3);

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

    function test_managePosition_baseToken_4626_full_decrease() public {
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        uint256 inputAmount = 3e18;

        // set up feed data for the vault, considering 1:1 ratio with its underlying, and add vault as a base token
        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(vault), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        caliber.addBaseToken(address(vault), VAULT_POS_ID);
        vm.stopPrank();

        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](1);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);

        assertEq(caliber.getPositionsLength(), 3);

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        instructions[0] = _build4626RedeemInstruction(
            address(caliber), VAULT_POS_ID, address(vault), vault.balanceOf(address(caliber))
        );

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        assertEq(caliber.getPositionsLength(), 3);
        assertEq(vault.balanceOf(address(caliber)), 0);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, 0);
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
        vm.prank(securityCouncil);
        instructions[0] = _build4626RedeemInstruction(address(caliber), VAULT_POS_ID, address(vault), sharesToRedeem);
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

    function test_cannotAccountForPositionWithoutExistingPosition() public {
        ICaliber.Instruction memory instruction = _build4626AccountingInstruction(address(caliber), 3, address(vault));

        vm.expectRevert(ICaliber.PositionDoesNotExist.selector);
        caliber.accountForPosition(instruction);
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

        // set baseToken position as non-base-token
        vm.prank(dao);
        caliber.setPositionAsNonBaseToken(BASE_TOKEN_POS_ID);

        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.accountForPosition(instructions[1]);

        // set baseToken back as a base token
        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        // replace end flag with null value in accounting output state with odd length
        delete instructions[1].state[2];
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.accountForPosition(instructions[1]);

        // put an end flag in the state after unequal number of assets and amounts
        bytes[] memory badState = new bytes[](4);
        badState[0] = instructions[1].state[0];
        badState[1] = instructions[1].state[1];
        badState[2] = abi.encode(address(1));
        badState[3] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);
        instructions[1].state = badState;

        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.accountForPosition(instructions[1]);
    }

    function test_cannotAccountForPositionWithNonExistingPosition() public {
        ICaliber.Instruction memory instruction =
            _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.expectRevert(ICaliber.PositionDoesNotExist.selector);
        caliber.accountForPosition(instruction);
    }

    function test_cannotAccountForPositionWithInvalidProof() public {
        vm.startPrank(dao);
        caliber.addBaseToken(address(baseToken), BASE_TOKEN_POS_ID);

        // set new token as a non-baseToken position
        MockERC20 testToken = new MockERC20("TestToken", "TST", 18);
        oracleRegistry.setTokenFeedData(
            address(testToken), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        caliber.addBaseToken(address(testToken), 4);
        deal(address(testToken), address(caliber), 1e18, true);
        caliber.setPositionAsNonBaseToken(4);
        vm.stopPrank();

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3e18, true);

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

        // use wrong posId
        instructions[1] = _build4626AccountingInstruction(address(caliber), 4, address(vault));
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instructions[1]);

        // use wrong commands
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[1].commands[2] = instructions[1].commands[1];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instructions[1]);

        // use wrong state
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instructions[1].state[1] = instructions[1].state[0];
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

        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](2);
        instructions[0] = _build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        instructions[1] = _build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(instructions);

        vm.prank(dao);
        caliber.setPositionAsBaseToken(VAULT_POS_ID, address(vault));

        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        caliber.accountForPosition(instructions[1]);
    }

    ///
    /// Helper functions
    ///

    function _build4626DepositInstruction(address _caliber, uint256 _posId, address _vault, uint256 _assets)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
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

        bytes32[] memory merkleProof = _getDeposit4626ScriptProof();

        uint128 stateBitmap = 0xa0000000000000000000000000000000;

        return ICaliber.Instruction(_posId, ICaliber.InstructionType.MANAGE, commands, state, stateBitmap, merkleProof);
    }

    function _build4626RedeemInstruction(address _caliber, uint256 _posId, address _vault, uint256 _shares)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
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

        bytes32[] memory merkleProof = _getRedeem4626ScriptProof();

        return ICaliber.Instruction(_posId, ICaliber.InstructionType.MANAGE, commands, state, stateBitmap, merkleProof);
    }

    function _build4626AccountingInstruction(address _caliber, uint256 _posId, address _vault)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        bytes32[] memory commands = new bytes32[](3);
        // "0x38d52e0f02ffffffffffff00" + _vault
        commands[0] = WeirollPlanner.buildCommand(
            IERC4626.asset.selector,
            0x02, // static call
            0xffffffffffff, // no input
            0x00, // store fixed size result at index 0 of state
            _vault
        );
        // "0x70a082310201ffffffffff01" + _vault
        commands[1] = WeirollPlanner.buildCommand(
            IERC20.balanceOf.selector,
            0x02, // static call
            0x01ffffffffff, // 1 input at index 1 of state
            0x01, // store fixed size result at index 1 of state
            _vault
        );
        // "0x4cdad5060201ffffffffff01" + _vault
        commands[2] = WeirollPlanner.buildCommand(
            IERC4626.previewRedeem.selector,
            0x02, // static call
            0x01ffffffffff, // 1 input at index 1 of state
            0x01, // store fixed size result at index 1 of state
            _vault
        );

        bytes[] memory state = new bytes[](3);
        state[1] = abi.encode(_caliber);
        state[2] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);

        uint128 stateBitmap = 0x40000000000000000000000000000000;

        bytes32[] memory merkleProof = _getAccounting4626ScriptProof();

        return
            ICaliber.Instruction(_posId, ICaliber.InstructionType.ACCOUNTING, commands, state, stateBitmap, merkleProof);
    }
}
