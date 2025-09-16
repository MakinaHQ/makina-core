// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract AccountForPositionBatch_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    uint256 private inputAmount;

    function setUp() public override {
        Caliber_Integration_Concrete_Test.setUp();

        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(baseToken));

        inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ReentrantCall() public {
        uint256 borrowInputAmount = 1e18;
        deal(address(baseToken), address(borrowModule), borrowInputAmount, true);
        ICaliber.Instruction memory borrowMgmtInstruction = WeirollUtils._buildMockBorrowModuleBorrowInstruction(
            BORROW_POS_ID, address(borrowModule), borrowInputAmount
        );
        ICaliber.Instruction memory borrowAcctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        ICaliber.Instruction[] memory instructions = new ICaliber.Instruction[](0);
        uint256[] memory groupIds = new uint256[](0);
        baseToken.scheduleReenter(
            MockERC20.Type.Before,
            address(caliber),
            abi.encodeCall(ICaliber.accountForPositionBatch, (instructions, groupIds))
        );

        vm.expectRevert();
        vm.prank(mechanic);
        caliber.managePosition(borrowMgmtInstruction, borrowAcctInstruction);
    }

    function test_RevertWhen_ZeroGroupId() public {
        uint256[] memory groupIds = new uint256[](1);

        vm.expectRevert(Errors.ZeroGroupId.selector);
        caliber.accountForPositionBatch(new ICaliber.Instruction[](0), groupIds);
    }

    function test_RevertWhen_ProvidedPositionNonExisting() public {
        // 1st instruction does not exist
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = WeirollUtils._build4626AccountingInstruction(address(caliber), 0, address(vault));
        vm.expectRevert(Errors.PositionDoesNotExist.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));

        // 2nd instruction does not exist
        accountingInstructions = new ICaliber.Instruction[](2);
        accountingInstructions[0] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        accountingInstructions[1] = WeirollUtils._build4626AccountingInstruction(address(caliber), 0, address(vault));
        vm.expectRevert(Errors.PositionDoesNotExist.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));
    }

    function test_RevertWhen_ProvidedInstructionNonAccountingType() public {
        // 1st instruction is not of accounting type
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(Errors.InvalidInstructionType.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));

        // 2nd instruction is not of accounting type
        accountingInstructions = new ICaliber.Instruction[](2);
        accountingInstructions[0] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        accountingInstructions[1] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vm.expectRevert(Errors.InvalidInstructionType.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));
    }

    function test_RevertWhen_ProvidedProofInvalid() public {
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(baseToken), 0);

        // 1st instruction uses wrong vault
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault2));
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));

        // 2nd instruction uses wrong vault
        accountingInstructions = new ICaliber.Instruction[](2);
        accountingInstructions[0] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        accountingInstructions[1] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault2));
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));
    }

    function test_RevertGiven_AccountingOutputStateInvalid() public {
        // 1st instruction has invalid accounting
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        // replace end flag with null value in accounting output state
        delete accountingInstructions[0].state[1];
        vm.expectRevert(Errors.InvalidAccounting.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));

        // 2nd instruction has invalid accounting
        accountingInstructions = new ICaliber.Instruction[](2);
        accountingInstructions[0] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        accountingInstructions[1] = accountingInstructions[0];
        // replace end flag with null value in accounting output state
        delete accountingInstructions[1].state[1];
        vm.expectRevert(Errors.InvalidAccounting.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));
    }

    function test_RevertWhen_GroupIdNotProvided() public {
        // create supply position
        uint256 supplyInputAmount = 2e18;
        deal(address(baseToken), address(caliber), supplyInputAmount, true);
        ICaliber.Instruction memory supplyMgmtInstruction = WeirollUtils._buildMockSupplyModuleSupplyInstruction(
            SUPPLY_POS_ID, address(supplyModule), supplyInputAmount
        );
        ICaliber.Instruction memory supplyAcctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        vm.prank(mechanic);
        caliber.managePosition(supplyMgmtInstruction, supplyAcctInstruction);

        // create borrow position
        uint256 borrowInputAmount = 1e18;
        deal(address(baseToken), address(borrowModule), borrowInputAmount, true);
        ICaliber.Instruction memory borrowMgmtInstruction = WeirollUtils._buildMockBorrowModuleBorrowInstruction(
            BORROW_POS_ID, address(borrowModule), borrowInputAmount
        );
        ICaliber.Instruction memory borrowAcctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(borrowMgmtInstruction, borrowAcctInstruction);

        // try to account for supply position without group ID
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = supplyAcctInstruction;
        vm.expectRevert(Errors.GroupIdNotProvided.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));

        // try to account for supply position with wrong group ID
        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = LENDING_MARKET_POS_GROUP_ID + 1;
        vm.expectRevert(Errors.GroupIdNotProvided.selector);
        caliber.accountForPositionBatch(accountingInstructions, groupIds);
    }

    function test_RevertWhen_MissingInstructionForGroup() public {
        // create supply position
        uint256 supplyInputAmount = 2e18;
        deal(address(baseToken), address(caliber), supplyInputAmount, true);
        ICaliber.Instruction memory supplyMgmtInstruction = WeirollUtils._buildMockSupplyModuleSupplyInstruction(
            SUPPLY_POS_ID, address(supplyModule), supplyInputAmount
        );
        ICaliber.Instruction memory supplyAcctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        vm.prank(mechanic);
        caliber.managePosition(supplyMgmtInstruction, supplyAcctInstruction);

        // create borrow position
        uint256 borrowInputAmount = 1e18;
        deal(address(baseToken), address(borrowModule), borrowInputAmount, true);
        ICaliber.Instruction memory borrowMgmtInstruction = WeirollUtils._buildMockBorrowModuleBorrowInstruction(
            BORROW_POS_ID, address(borrowModule), borrowInputAmount
        );
        ICaliber.Instruction memory borrowAcctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(borrowMgmtInstruction, borrowAcctInstruction);

        // try to account for supply position without borrow position
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = supplyAcctInstruction;
        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = LENDING_MARKET_POS_GROUP_ID;
        vm.expectRevert(abi.encodeWithSelector(Errors.MissingInstructionForGroup.selector, LENDING_MARKET_POS_GROUP_ID));
        caliber.accountForPositionBatch(accountingInstructions, groupIds);
    }

    function test_AccountForPositionBatch_GroupSizeOne() public {
        // create supply position
        uint256 supplyInputAmount = 2e18;
        deal(address(baseToken), address(caliber), supplyInputAmount, true);
        ICaliber.Instruction memory supplyMgmtInstruction = WeirollUtils._buildMockSupplyModuleSupplyInstruction(
            SUPPLY_POS_ID, address(supplyModule), supplyInputAmount
        );
        ICaliber.Instruction memory supplyAcctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        vm.prank(mechanic);
        caliber.managePosition(supplyMgmtInstruction, supplyAcctInstruction);

        // account for supply position without group ID
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] = supplyAcctInstruction;
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));

        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, supplyInputAmount * PRICE_B_A);

        // account for supply position with group ID
        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = LENDING_MARKET_POS_GROUP_ID;

        uint256[] memory values;
        int256[] memory changes;
        (values, changes) = caliber.accountForPositionBatch(accountingInstructions, groupIds);

        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, supplyInputAmount * PRICE_B_A);
        assertEq(values.length, 1);
        assertEq(values[0], supplyInputAmount * PRICE_B_A);
        assertEq(changes.length, 1);
        assertEq(changes[0], 0);
    }

    function test_AccountForPositionBatch_Group() public {
        // create supply position
        uint256 supplyInputAmount = 2e18;
        deal(address(baseToken), address(caliber), supplyInputAmount, true);
        ICaliber.Instruction memory supplyMgmtInstruction = WeirollUtils._buildMockSupplyModuleSupplyInstruction(
            SUPPLY_POS_ID, address(supplyModule), supplyInputAmount
        );
        ICaliber.Instruction memory supplyAcctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        vm.prank(mechanic);
        caliber.managePosition(supplyMgmtInstruction, supplyAcctInstruction);

        // create borrow position
        uint256 borrowInputAmount = 1e18;
        deal(address(baseToken), address(borrowModule), borrowInputAmount, true);
        ICaliber.Instruction memory borrowMgmtInstruction = WeirollUtils._buildMockBorrowModuleBorrowInstruction(
            BORROW_POS_ID, address(borrowModule), borrowInputAmount
        );
        ICaliber.Instruction memory borrowAcctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(borrowMgmtInstruction, borrowAcctInstruction);

        // account for supply and borrow positions in a batch
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](2);
        accountingInstructions[0] = supplyAcctInstruction;
        accountingInstructions[1] = borrowAcctInstruction;
        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = LENDING_MARKET_POS_GROUP_ID;

        uint256[] memory values;
        int256[] memory changes;
        (values, changes) = caliber.accountForPositionBatch(accountingInstructions, groupIds);

        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, supplyInputAmount * PRICE_B_A);
        assertEq(caliber.getPosition(BORROW_POS_ID).value, borrowInputAmount * PRICE_B_A);
        assertEq(values.length, 2);
        assertEq(values[0], supplyInputAmount * PRICE_B_A);
        assertEq(values[1], borrowInputAmount * PRICE_B_A);
        assertEq(changes.length, 2);
        assertEq(changes[0], 0);
        assertEq(changes[1], 0);

        caliber.accountForPositionBatch(accountingInstructions, groupIds);
    }

    function test_AccountForPositionBatch_NoGroup() public {
        uint256 previewShares = vault.previewDeposit(inputAmount);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, inputAmount * PRICE_B_A);

        uint256 yield = 1e18;
        deal(address(baseToken), address(vault), inputAmount + yield, true);

        uint256 previewAssets = vault.previewRedeem(vault.balanceOf(address(caliber)));

        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        uint256[] memory values;
        int256[] memory changes;
        (values, changes) = caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, previewAssets * PRICE_B_A);
        assertEq(values.length, 1);
        assertEq(values[0], previewAssets * PRICE_B_A);
        assertEq(changes.length, 1);
        assertApproxEqRel(changes[0], int256(yield * PRICE_B_A), 1e10);
    }

    function test_RevertGiven_WrongRoot() public {
        // schedule root update with a wrong root
        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(keccak256(abi.encodePacked("wrongRoot")));

        // accounting can still be executed while the update is pending
        ICaliber.Instruction[] memory accountingInstructions = new ICaliber.Instruction[](1);
        accountingInstructions[0] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));

        skip(caliber.timelockDuration());

        // accounting cannot be executed after the update takes effect
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));

        // schedule root update with the correct root
        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(MerkleProofs._getAllowedInstrMerkleRoot());

        // accounting cannot be executed while the update is pending
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));

        skip(caliber.timelockDuration());

        // accounting can be executed after the update takes effect
        caliber.accountForPositionBatch(accountingInstructions, new uint256[](0));
    }
}
