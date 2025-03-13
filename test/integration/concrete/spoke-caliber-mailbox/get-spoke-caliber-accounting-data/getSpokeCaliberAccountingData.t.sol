// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ISpokeCaliberMailbox} from "src/interfaces/ISpokeCaliberMailbox.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Integration_Concrete_Spoke_Test} from "../../IntegrationConcrete.t.sol";

contract GetSpokeCaliberAccountingData_Integration_Concrete_Test is Integration_Concrete_Spoke_Test {
    function setUp() public override {
        Integration_Concrete_Spoke_Test.setUp();
        _setUpCaliberMerkleRoot(caliber);
    }

    function test_RevertGiven_PositionStale() public withTokenAsBT(address(baseToken)) {
        // create a supply position
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        ICaliber.Instruction[] memory supplyModuleInstructions = new ICaliber.Instruction[](2);
        supplyModuleInstructions[0] =
            WeirollUtils._buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        supplyModuleInstructions[1] = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, address(supplyModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(supplyModuleInstructions);

        skip(DEFAULT_CALIBER_POS_STALE_THRESHOLD + 1);

        vm.expectRevert(abi.encodeWithSelector(ICaliber.PositionAccountingStale.selector, SUPPLY_POS_ID));
        spokeCaliberMailbox.getSpokeCaliberAccountingData();
    }

    function test_GetPositionsValues() public withTokenAsBT(address(baseToken)) {
        uint256 aInputAmount = 3e18;
        uint256 bInputAmount = 5e18;

        // increase accounting token position
        deal(address(accountingToken), address(caliber), aInputAmount, true);

        // create supply position
        deal(address(baseToken), address(caliber), bInputAmount, true);
        ICaliber.Instruction[] memory supplyModuleInstructions = new ICaliber.Instruction[](2);
        supplyModuleInstructions[0] =
            WeirollUtils._buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), bInputAmount);
        supplyModuleInstructions[1] = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, address(supplyModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(supplyModuleInstructions);

        // check accounting token position is correctly accounted for in AUM
        ISpokeCaliberMailbox.SpokeCaliberAccountingData memory data =
            spokeCaliberMailbox.getSpokeCaliberAccountingData();
        assertEq(data.netAum, aInputAmount + PRICE_B_A * bInputAmount);
        assertEq(data.totalReceivedFromHM.length, 0);
        assertEq(data.totalSentToHM.length, 0);
        assertEq(data.positions.length, 1);
        assertEq(data.baseTokens.length, 2);
        _checkEncodedCaliberPosValue(data.positions[0], SUPPLY_POS_ID, PRICE_B_A * bInputAmount, false);
        _checkEncodedCaliberBTValue(data.baseTokens[0], address(accountingToken), aInputAmount);
        _checkEncodedCaliberBTValue(data.baseTokens[1], address(baseToken), 0);

        skip(1 hours);

        caliber.accountForPosition(supplyModuleInstructions[1]);

        // check data is the same after a day
        data = spokeCaliberMailbox.getSpokeCaliberAccountingData();
        assertEq(data.netAum, aInputAmount + PRICE_B_A * bInputAmount);
        assertEq(data.totalReceivedFromHM.length, 0);
        assertEq(data.totalSentToHM.length, 0);
        assertEq(data.positions.length, 1);
        assertEq(data.baseTokens.length, 2);
        _checkEncodedCaliberPosValue(data.positions[0], SUPPLY_POS_ID, PRICE_B_A * bInputAmount, false);
        _checkEncodedCaliberBTValue(data.baseTokens[0], address(accountingToken), aInputAmount);
        _checkEncodedCaliberBTValue(data.baseTokens[1], address(baseToken), 0);
    }
}
