// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract AccountForPosition_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    uint256 private vaultInputAmount;
    uint256 private supplyInputAmount;

    function setUp() public override {
        Caliber_Integration_Concrete_Test.setUp();

        vm.prank(riskManagerTimelock);
        caliber.addBaseToken(address(baseToken));

        vaultInputAmount = 2e18;
        supplyInputAmount = 3e18;

        deal(address(baseToken), address(caliber), vaultInputAmount + supplyInputAmount, true);

        // create vault position
        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), vaultInputAmount);
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // create supply position
        ICaliber.Instruction memory supplyMgmtInstruction = WeirollUtils._buildMockSupplyModuleSupplyInstruction(
            SUPPLY_POS_ID, address(supplyModule), supplyInputAmount
        );
        ICaliber.Instruction memory supplyAcctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        vm.prank(mechanic);
        caliber.managePosition(supplyMgmtInstruction, supplyAcctInstruction);
    }

    function test_RevertWhen_ProvidedPositionNonExisting() public {
        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), 0, address(vault));

        vm.expectRevert(Errors.PositionDoesNotExist.selector);
        caliber.accountForPosition(instruction);
    }

    function test_RevertWhen_ProvidedInstructionNonAccountingType() public {
        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), vaultInputAmount);

        vm.expectRevert(Errors.InvalidInstructionType.selector);
        caliber.accountForPosition(instruction);
    }

    function test_RevertWhen_ProvidedProofInvalid() public {
        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(baseToken), 0);
        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault2));
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong posId
        instruction =
            WeirollUtils._buildMockPoolAccountingInstruction(address(caliber), VAULT_POS_ID, address(pool), true);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong isDebt
        instruction = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instruction.isDebt = true;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong groupId
        instruction = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instruction.groupId = LENDING_MARKET_POS_GROUP_ID;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong affected tokens list
        instruction = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instruction.affectedTokens[0] = address(0);
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong commands
        instruction = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instruction.commands[2] = instruction.commands[1];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong state
        instruction = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instruction.state[2] = instruction.state[0];
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong bitmap
        instruction = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instruction.stateBitmap = 0;
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);
    }

    function test_RevertGiven_AccountingOutputStateInvalid() public {
        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        // replace end flag with null value in accounting output state
        delete instruction.state[1];
        vm.expectRevert(Errors.InvalidAccounting.selector);
        caliber.accountForPosition(instruction);
    }

    function test_RevertGiven_PositionGrouped() public {
        // create borrow module position
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

        vm.expectRevert(Errors.PositionIsGrouped.selector);
        caliber.accountForPosition(borrowAcctInstruction);

        ICaliber.Instruction memory supplyAcctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );
        vm.expectRevert(Errors.PositionIsGrouped.selector);
        caliber.accountForPosition(supplyAcctInstruction);
    }

    function test_AccountForPosition_4626() public {
        uint256 previewShares = vault.previewDeposit(vaultInputAmount);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, vaultInputAmount * PRICE_B_A);

        uint256 yield = 1e18;
        deal(address(baseToken), address(vault), vaultInputAmount + yield, true);

        uint256 previewAssets = vault.previewRedeem(vault.balanceOf(address(caliber)));

        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        caliber.accountForPosition(instruction);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, previewAssets * PRICE_B_A);
    }

    function test_AccountForPosition_SupplyModule() public {
        assertEq(supplyModule.collateralOf(address(caliber)), supplyInputAmount);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, supplyInputAmount * PRICE_B_A);

        // call succeeds as group is of size 1
        ICaliber.Instruction memory supplyAcctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );
        caliber.accountForPosition(supplyAcctInstruction);

        // increase supplyModule rate
        supplyModule.setRateBps(10_000 * 2);

        caliber.accountForPosition(supplyAcctInstruction);

        assertEq(supplyModule.collateralOf(address(caliber)), supplyInputAmount * 2);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, supplyInputAmount * PRICE_B_A * 2);

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

        // close borrow position
        vm.prank(mechanic);
        ICaliber.Instruction memory repayMgmtInstruction =
            WeirollUtils._buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), borrowInputAmount);
        vm.prank(mechanic);
        caliber.managePosition(repayMgmtInstruction, borrowAcctInstruction);

        // call succeeds as group is of size 1
        caliber.accountForPosition(supplyAcctInstruction);

        assertEq(supplyModule.collateralOf(address(caliber)), supplyInputAmount * 2);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, supplyInputAmount * PRICE_B_A * 2);
    }

    function test_RevertGiven_WrongRoot() public {
        // schedule root update with a wrong root
        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(keccak256(abi.encodePacked("wrongRoot")));

        // accounting can still be executed while the update is pending
        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        caliber.accountForPosition(instruction);

        skip(caliber.timelockDuration());

        // accounting cannot be executed after the update takes effect
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // schedule root update with the correct root
        vm.prank(riskManager);
        caliber.scheduleAllowedInstrRootUpdate(MerkleProofs._getAllowedInstrMerkleRoot());

        // accounting cannot be executed while the update is pending
        vm.expectRevert(Errors.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        skip(caliber.timelockDuration());

        // accounting can be executed after the update takes effect
        caliber.accountForPosition(instruction);
    }
}
