// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {DeployMakinaCore} from "../script/DeployMakinaCore.s.sol";
import {DeployCalibers} from "../script/DeployCalibers.s.sol";
import {ICaliber} from "../src/interfaces/ICaliber.sol";

import {Base_Test} from "./BaseTest.sol";

contract Deploy_Test is Base_Test {
    using stdJson for string;

    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public jsonConstants;

    // Scripts to test
    DeployMakinaCore public deployMakinaCore;
    DeployCalibers public deployCalibers;

    function setUp() public override {
        deployMakinaCore = new DeployMakinaCore();
        deployCalibers = new DeployCalibers();

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/constants/");
        path = string.concat(path, constantsFilename);

        jsonConstants = vm.readFile(path);
        dao = abi.decode(vm.parseJson(jsonConstants, ".dao"), (address));
        securityCouncil = abi.decode(vm.parseJson(jsonConstants, ".securityCouncil"), (address));
    }

    function testLoadedState() public view {
        assertTrue(dao != address(0));
        assertTrue(securityCouncil != address(0));
    }

    function testDeployScript() public {
        deployMakinaCore.run();
        deployCalibers.run();

        // Check that OracleRegistry is correctly set up
        DeployMakinaCore.PriceFeedData[] memory _priceFeedData =
            abi.decode(vm.parseJson(jsonConstants, ".priceFeedData"), (DeployMakinaCore.PriceFeedData[]));
        for (uint256 i; i < _priceFeedData.length; i++) {
            (address feed1, address feed2) = deployMakinaCore.oracleRegistry().getTokenFeedData(_priceFeedData[i].token);
            assertEq(_priceFeedData[i].feed1, feed1);
            assertEq(_priceFeedData[i].feed2, feed2);
        }

        // Check that Swapper is correctly set up
        DeployMakinaCore.DexAggregatorData[] memory _dexAggregatorsData =
            abi.decode(vm.parseJson(jsonConstants, ".dexAggregatorsTargets"), (DeployMakinaCore.DexAggregatorData[]));
        for (uint256 i; i < _dexAggregatorsData.length; i++) {
            (address approvalTarget, address executionTarget) =
                deployMakinaCore.swapper().dexAggregatorTargets(_dexAggregatorsData[i].aggregatorId);
            assertEq(_dexAggregatorsData[i].approvalTarget, approvalTarget);
            assertEq(_dexAggregatorsData[i].executionTarget, executionTarget);
        }

        // Check that Calibers are correctly set up
        DeployCalibers.CaliberDeploymentParams[] memory _calibersToDeploy =
            abi.decode(vm.parseJson(jsonConstants, ".calibersToDeploy"), (DeployCalibers.CaliberDeploymentParams[]));
        for (uint256 i; i < _calibersToDeploy.length; i++) {
            address _caliber = deployCalibers.deployedCalibers(i);
            assertTrue(deployMakinaCore.caliberFactory().isCaliber(_caliber));
            // @TODO verify that the mailbox is correctly set up
            assertEq(ICaliber(_caliber).accountingToken(), _calibersToDeploy[i].accountingToken);
            assertEq(ICaliber(_caliber).getPositionId(0), _calibersToDeploy[i].accountingTokenPosId);
            assertEq(ICaliber(_caliber).allowedInstrRoot(), _calibersToDeploy[i].initialAllowedInstrRoot);
            assertEq(ICaliber(_caliber).maxMgmtLossBps(), _calibersToDeploy[i].initialMaxMgmtLossBps);
            assertEq(ICaliber(_caliber).maxSwapLossBps(), _calibersToDeploy[i].initialMaxSwapLossBps);
            assertEq(ICaliber(_caliber).mechanic(), _calibersToDeploy[i].initialMechanic);
            assertEq(ICaliber(_caliber).positionStaleThreshold(), _calibersToDeploy[i].initialPositionStaleThreshold);
            assertEq(ICaliber(_caliber).timelockDuration(), _calibersToDeploy[i].initialTimelockDuration);
        }
    }
}
