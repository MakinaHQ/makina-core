// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {VM} from "@enso-weiroll/VM.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract ManageFlashLoan_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        MockERC20 token = new MockERC20("Token", "TKN", 18);

        uint256 flashLoanAmount = 1e18;
        deal(address(token), address(flashLoanModule), 2 * flashLoanAmount, true);

        ICaliber.Instruction memory flMgmtInstruction = WeirollUtils._buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        ICaliber.Instruction memory mgmtInstruction = WeirollUtils._buildMockFlashLoanModuleDummyLoopInstruction(
            LOOP_POS_ID, address(flashLoanModule), address(token), flashLoanAmount, flMgmtInstruction
        );
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID);

        flashLoanModule.setReentrancyMode(true);

        vm.expectRevert(
            abi.encodeWithSelector(
                VM.ExecutionFailed.selector,
                0,
                address(flashLoanModule),
                string(abi.encodePacked(ICaliber.ManageFlashLoanReentrantCall.selector))
            )
        );
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_CallerNotFlashLoanModule() public {
        ICaliber.Instruction memory dummyInstruction;
        vm.expectRevert(ICaliber.NotFlashLoanModule.selector);
        caliber.manageFlashLoan(dummyInstruction, address(0), 0);
    }

    function test_RevertWhen_DirectCall() public {
        ICaliber.Instruction memory dummyInstruction;
        vm.expectRevert(ICaliber.DirectManageFlashLoanCall.selector);
        vm.prank(address(flashLoanModule));
        caliber.manageFlashLoan(dummyInstruction, address(0), 0);
    }

    function test_RevertWhen_ProvidedInstructionNonFlashLoanManagementType() public {
        MockERC20 token = new MockERC20("TOKEN", "TKN", 18);

        uint256 flashLoanAmount = 1e18;
        deal(address(token), address(flashLoanModule), flashLoanAmount, true);

        ICaliber.Instruction memory flMgmtInstruction = WeirollUtils._buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        flMgmtInstruction.instructionType = ICaliber.InstructionType.MANAGEMENT;
        ICaliber.Instruction memory mgmtInstruction = WeirollUtils._buildMockFlashLoanModuleDummyLoopInstruction(
            LOOP_POS_ID, address(flashLoanModule), address(token), flashLoanAmount, flMgmtInstruction
        );
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID);

        vm.expectRevert(
            abi.encodeWithSelector(
                VM.ExecutionFailed.selector,
                0,
                address(flashLoanModule),
                string(abi.encodePacked(ICaliber.InvalidInstructionType.selector))
            )
        );
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_ProvidedInstructionsUnmatching() public {
        MockERC20 token = new MockERC20("TOKEN", "TKN", 18);

        uint256 flashLoanAmount = 1e18;
        deal(address(token), address(flashLoanModule), flashLoanAmount, true);

        bytes memory errorData = abi.encodeWithSelector(
            VM.ExecutionFailed.selector,
            0,
            address(flashLoanModule),
            string(abi.encodePacked(ICaliber.UnmatchingInstructions.selector))
        );

        // instructions have different positionId
        ICaliber.Instruction memory flMgmtInstruction =
            WeirollUtils._buildManageFlashLoanDummyInstruction(LOOP_POS_ID + 1);
        ICaliber.Instruction memory mgmtInstruction = WeirollUtils._buildMockFlashLoanModuleDummyLoopInstruction(
            LOOP_POS_ID, address(flashLoanModule), address(token), flashLoanAmount, flMgmtInstruction
        );
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID);
        vm.expectRevert(errorData);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // instructions have different isDebt flag
        flMgmtInstruction = WeirollUtils._buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        flMgmtInstruction.isDebt = true;
        vm.expectRevert(errorData);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);
    }

    function test_RevertWhen_InstructionsAreDebt() public {
        ICaliber.Instruction memory flMgmtInstruction = WeirollUtils._buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        flMgmtInstruction.isDebt = true;

        // proceed by overwriting the caliber storage as this case is hardly reachable
        bytes32 caliberStorageLocation =
            keccak256(abi.encode(uint256(keccak256("makina.storage.Caliber")) - 1)) & ~bytes32(uint256(0xff));

        // set _managedPositionId to LOOP_POS_ID
        vm.store(address(caliber), bytes32(uint256(caliberStorageLocation) + 11), bytes32(LOOP_POS_ID));

        // set _isManagedPositionDebt to true
        vm.store(address(caliber), bytes32(uint256(caliberStorageLocation) + 12), bytes32(uint256(1)));

        vm.expectRevert(ICaliber.InvalidDebtFlag.selector);
        vm.prank(address(flashLoanModule));
        caliber.manageFlashLoan(flMgmtInstruction, address(0), 0);
    }

    function test_ManageFlashLoan() public {
        MockERC20 token = new MockERC20("TOKEN", "TKN", 18);

        uint256 flashLoanAmount = 1e18;
        deal(address(token), address(flashLoanModule), flashLoanAmount, true);

        ICaliber.Instruction memory flMgmtInstruction = WeirollUtils._buildManageFlashLoanDummyInstruction(LOOP_POS_ID);
        ICaliber.Instruction memory mgmtInstruction = WeirollUtils._buildMockFlashLoanModuleDummyLoopInstruction(
            LOOP_POS_ID, address(flashLoanModule), address(token), flashLoanAmount, flMgmtInstruction
        );
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._buildMockFlashLoanModuleDummyAccountingInstruction(LOOP_POS_ID);

        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        assertEq(token.balanceOf(address(flashLoanModule)), flashLoanAmount);
        assertEq(token.balanceOf(address(caliber)), 0);
    }
}
