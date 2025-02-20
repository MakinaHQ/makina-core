// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {DeployMakinaCoreShared} from "../script/DeployMakinaCoreShared.s.sol";
import {DeployMakinaCoreHub} from "../script/DeployMakinaCoreHub.s.sol";
import {DeployMakinaCoreSpoke} from "../script/DeployMakinaCoreSpoke.s.sol";
import {DeploySpokeCalibers} from "../script/DeploySpokeCalibers.s.sol";
import {ICaliber} from "../src/interfaces/ICaliber.sol";

import {Base_Test} from "./BaseTest.sol";

contract Deploy_Test is Base_Test {
    using stdJson for string;

    string public hubConstantsFilename = vm.envString("HUB_CONSTANTS_FILENAME");
    string public spokeConstantsFilename = vm.envString("SPOKE_CONSTANTS_FILENAME");

    string public hubJsonConstants;
    string public spokeJsonConstants;

    // Scripts to test
    DeployMakinaCoreHub public deployMakinaCoreHub;
    DeployMakinaCoreSpoke public deployMakinaCoreSpoke;
    DeploySpokeCalibers public deploySpokeCalibers;

    function setUp() public override {
        deployMakinaCoreHub = new DeployMakinaCoreHub();
        deployMakinaCoreSpoke = new DeployMakinaCoreSpoke();
        deploySpokeCalibers = new DeploySpokeCalibers();

        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/script/constants/");
        string memory hubInputPath = string.concat(basePath, hubConstantsFilename);
        string memory spokeInputPath = string.concat(basePath, spokeConstantsFilename);

        hubJsonConstants = vm.readFile(hubInputPath);
        spokeJsonConstants = vm.readFile(spokeInputPath);
    }

    function testLoadedState() public view {
        address hubDao = abi.decode(vm.parseJson(hubJsonConstants, ".dao"), (address));
        address hubSecurityCouncil = abi.decode(vm.parseJson(hubJsonConstants, ".securityCouncil"), (address));
        assertTrue(hubDao != address(0));
        assertTrue(hubSecurityCouncil != address(0));

        address spokeDao = abi.decode(vm.parseJson(spokeJsonConstants, ".dao"), (address));
        address spokeSecurityCouncil = abi.decode(vm.parseJson(spokeJsonConstants, ".securityCouncil"), (address));
        assertTrue(spokeDao != address(0));
        assertTrue(spokeSecurityCouncil != address(0));
    }

    function testDeployScript() public {
        deployMakinaCoreHub.run();
        deployMakinaCoreSpoke.run();
        deploySpokeCalibers.run();

        // Check that OracleRegistry is correctly set up in Hub
        DeployMakinaCoreShared.PriceFeedData[] memory _priceFeedData =
            abi.decode(vm.parseJson(hubJsonConstants, ".priceFeedData"), (DeployMakinaCoreShared.PriceFeedData[]));
        for (uint256 i; i < _priceFeedData.length; i++) {
            (address feed1, address feed2) =
                deployMakinaCoreHub.oracleRegistry().getTokenFeedData(_priceFeedData[i].token);
            assertEq(_priceFeedData[i].feed1, feed1);
            assertEq(_priceFeedData[i].feed2, feed2);
        }

        // Check that OracleRegistry is correctly set up in Spoke
        _priceFeedData =
            abi.decode(vm.parseJson(spokeJsonConstants, ".priceFeedData"), (DeployMakinaCoreShared.PriceFeedData[]));
        for (uint256 i; i < _priceFeedData.length; i++) {
            (address feed1, address feed2) =
                deployMakinaCoreSpoke.oracleRegistry().getTokenFeedData(_priceFeedData[i].token);
            assertEq(_priceFeedData[i].feed1, feed1);
            assertEq(_priceFeedData[i].feed2, feed2);
        }

        // Check that Swapper is correctly set up in both Hub
        DeployMakinaCoreShared.DexAggregatorData[] memory _dexAggregatorsData = abi.decode(
            vm.parseJson(hubJsonConstants, ".dexAggregatorsTargets"), (DeployMakinaCoreShared.DexAggregatorData[])
        );
        for (uint256 i; i < _dexAggregatorsData.length; i++) {
            (address approvalTarget, address executionTarget) =
                deployMakinaCoreHub.swapper().dexAggregatorTargets(_dexAggregatorsData[i].aggregatorId);
            assertEq(_dexAggregatorsData[i].approvalTarget, approvalTarget);
            assertEq(_dexAggregatorsData[i].executionTarget, executionTarget);
        }

        // Check that Swapper is correctly set up in both Spoke
        _dexAggregatorsData = abi.decode(
            vm.parseJson(spokeJsonConstants, ".dexAggregatorsTargets"), (DeployMakinaCoreShared.DexAggregatorData[])
        );
        for (uint256 i; i < _dexAggregatorsData.length; i++) {
            (address approvalTarget, address executionTarget) =
                deployMakinaCoreSpoke.swapper().dexAggregatorTargets(_dexAggregatorsData[i].aggregatorId);
            assertEq(_dexAggregatorsData[i].approvalTarget, approvalTarget);
            assertEq(_dexAggregatorsData[i].executionTarget, executionTarget);
        }

        // Check that Calibers are correctly set up
        DeploySpokeCalibers.DeploymentParams[] memory _calibersToDeploy =
            abi.decode(vm.parseJson(spokeJsonConstants, ".calibersToDeploy"), (DeploySpokeCalibers.DeploymentParams[]));
        for (uint256 i; i < _calibersToDeploy.length; i++) {
            address _caliber = deploySpokeCalibers.deployedCalibers(i);
            assertTrue(deployMakinaCoreSpoke.spokeCaliberFactory().isCaliber(_caliber));
            // @TODO verify that the mailbox is correctly set up
            assertEq(ICaliber(_caliber).accountingToken(), _calibersToDeploy[i].accountingToken);
            assertEq(ICaliber(_caliber).getPositionId(0), _calibersToDeploy[i].accountingTokenPosId);
            assertEq(ICaliber(_caliber).allowedInstrRoot(), _calibersToDeploy[i].initialAllowedInstrRoot);
            assertEq(
                ICaliber(_caliber).maxPositionIncreaseLossBps(), _calibersToDeploy[i].initialMaxPositionIncreaseLossBps
            );
            assertEq(
                ICaliber(_caliber).maxPositionDecreaseLossBps(), _calibersToDeploy[i].initialMaxPositionDecreaseLossBps
            );
            assertEq(ICaliber(_caliber).maxSwapLossBps(), _calibersToDeploy[i].initialMaxSwapLossBps);
            assertEq(ICaliber(_caliber).mechanic(), _calibersToDeploy[i].initialMechanic);
            assertEq(ICaliber(_caliber).positionStaleThreshold(), _calibersToDeploy[i].initialPositionStaleThreshold);
            assertEq(ICaliber(_caliber).timelockDuration(), _calibersToDeploy[i].initialTimelockDuration);
        }
    }
}
