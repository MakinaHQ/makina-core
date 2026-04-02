// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract IsValidSignature_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    uint256 internal newMechanicPk;
    address internal newMechanic;

    uint256 internal newSecurityCouncilPk;
    address internal newSecurityCouncil;

    function setUp() public override {
        Caliber_Integration_Concrete_Test.setUp();

        (newMechanic, newMechanicPk) = makeAddrAndKey("newMechanic");
        (newSecurityCouncil, newSecurityCouncilPk) = makeAddrAndKey("newSecurityCouncil");

        vm.startPrank(dao);
        machine.setMechanic(newMechanic);
        machine.setSecurityCouncil(newSecurityCouncil);
        vm.stopPrank();
    }

    function test_IsValidSignature() public {
        bytes32 hash = keccak256("message");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(newMechanicPk, hash);
        bytes memory mechanicSignature = abi.encodePacked(r, s, v);

        (v, r, s) = vm.sign(newSecurityCouncilPk, hash);
        bytes memory securityCouncilSignature = abi.encodePacked(r, s, v);

        assertEq(caliber.isValidSignature(hash, mechanicSignature), IERC1271.isValidSignature.selector);
        assertEq(caliber.isValidSignature(hash, securityCouncilSignature), bytes4(0xffffffff));

        vm.prank(newSecurityCouncil);
        machine.setRecoveryMode(true);

        assertEq(caliber.isValidSignature(hash, mechanicSignature), bytes4(0xffffffff));
        assertEq(caliber.isValidSignature(hash, securityCouncilSignature), IERC1271.isValidSignature.selector);
    }
}
