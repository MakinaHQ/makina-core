// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {MockERC4626} from "test/mocks/MockERC4626.sol";
import {MerkleProofs} from "test/utils/MerkleProofs.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract AccountForPosition_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    uint256 private inputAmount;

    function setUp() public override {
        Caliber_Integration_Concrete_Test.setUp();

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID);

        inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction[] memory vaultInstructions = new ICaliber.Instruction[](2);
        vaultInstructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        vaultInstructions[1] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        vm.prank(mechanic);
        caliber.managePosition(vaultInstructions);
    }

    function test_cannotAccountForPositionWithNonExistingPosition() public {
        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), 0, address(vault));

        vm.expectRevert(ICaliber.PositionDoesNotExist.selector);
        caliber.accountForPosition(instruction);
    }

    function test_cannotAccountForPositionWithBaseTokenPosition() public {
        ICaliber.Instruction memory instruction = WeirollUtils._build4626AccountingInstruction(
            address(caliber), HUB_CALIBER_BASE_TOKEN_1_POS_ID, address(vault)
        );

        vm.expectRevert(ICaliber.BaseTokenPosition.selector);
        caliber.accountForPosition(instruction);
    }

    function test_cannotAccountForPositionWithNonAccountingInstruction() public {
        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);

        vm.expectRevert(ICaliber.InvalidInstructionType.selector);
        caliber.accountForPosition(instruction);
    }

    function test_cannotAccountForPositionWithInvalidProof() public {
        // use wrong vault
        MockERC4626 vault2 = new MockERC4626("Vault2", "VLT2", IERC20(baseToken), 0);
        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault2));
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong affected tokens list
        instruction = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instruction.affectedTokens[0] = address(0);
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong commands
        instruction = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instruction.commands[2] = instruction.commands[1];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong state
        instruction = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instruction.state[2] = instruction.state[0];
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // use wrong bitmap
        instruction = WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        instruction.stateBitmap = 0;
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);
    }

    function test_cannotAccountForPositionWithInvalidAccountingOutputState() public {
        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        // replace end flag with null value in accounting output state
        delete instruction.state[1];
        vm.expectRevert(ICaliber.InvalidAccounting.selector);
        caliber.accountForPosition(instruction);
    }

    function test_accountForPosition_4626() public {
        uint256 previewShares = vault.previewDeposit(inputAmount);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, inputAmount * PRICE_B_A);

        uint256 yield = 1e18;
        deal(address(baseToken), address(vault), inputAmount + yield, true);

        uint256 previewAssets = vault.previewRedeem(vault.balanceOf(address(caliber)));

        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        caliber.accountForPosition(instruction);

        assertEq(vault.balanceOf(address(caliber)), previewShares);
        assertEq(caliber.getPosition(VAULT_POS_ID).value, previewAssets * PRICE_B_A);
    }

    function test_cannotAccountForPositionWithWrongRoot() public {
        // schedule root update with a wrong root
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(keccak256(abi.encodePacked("wrongRoot")));

        // accounting can still be executed while the update is pending
        ICaliber.Instruction memory instruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        caliber.accountForPosition(instruction);

        skip(caliber.timelockDuration());

        // accounting cannot be executed after the update takes effect
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        // schedule root update with the correct root
        vm.prank(dao);
        caliber.scheduleAllowedInstrRootUpdate(MerkleProofs._getAllowedInstrMerkleRoot());

        // accounting cannot be executed while the update is pending
        vm.expectRevert(ICaliber.InvalidInstructionProof.selector);
        caliber.accountForPosition(instruction);

        skip(caliber.timelockDuration());

        // accounting can be executed after the update takes effect
        caliber.accountForPosition(instruction);
    }
}
