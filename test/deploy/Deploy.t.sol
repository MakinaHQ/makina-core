// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";
import {stdStorage, StdStorage} from "forge-std/StdStorage.sol";

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ChainsData} from "test/utils/ChainsData.sol";
import {DeployMakinaCoreHub} from "script/deployments/DeployMakinaCoreHub.s.sol";
import {DeployMakinaCoreSpoke} from "script/deployments/DeployMakinaCoreSpoke.s.sol";
import {DeploySpokeCaliber} from "script/deployments/DeploySpokeCaliber.s.sol";
import {DeployHubMachine} from "script/deployments/DeployHubMachine.s.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IHubDualMailbox} from "src/interfaces/IHubDualMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";

import {Base_Test} from "../base/Base.t.sol";

contract Deploy_Test is Base_Test {
    using stdJson for string;
    using stdStorage for StdStorage;

    // Scripts to test
    DeployMakinaCoreHub public deployMakinaCoreHub;
    DeployMakinaCoreSpoke public deployMakinaCoreSpoke;
    DeploySpokeCaliber public deploySpokeCaliber;
    DeployHubMachine public deployHubMachine;

    function testLoadedState() public {
        vm.setEnv("HUB_CORE_PARAMS_FILENAME", "Mainnet-Test.json");
        vm.setEnv("SPOKE_CORE_PARAMS_FILENAME", "Base-Test.json");

        deployMakinaCoreHub = new DeployMakinaCoreHub();
        deployMakinaCoreSpoke = new DeployMakinaCoreSpoke();

        address hubDao = abi.decode(vm.parseJson(deployMakinaCoreHub.paramsJson(), ".dao"), (address));
        address hubSecurityCouncil =
            abi.decode(vm.parseJson(deployMakinaCoreHub.paramsJson(), ".securityCouncil"), (address));
        assertTrue(hubDao != address(0));
        assertTrue(hubSecurityCouncil != address(0));

        address spokeDao = abi.decode(vm.parseJson(deployMakinaCoreSpoke.paramsJson(), ".dao"), (address));
        address spokeSecurityCouncil =
            abi.decode(vm.parseJson(deployMakinaCoreSpoke.paramsJson(), ".securityCouncil"), (address));
        assertTrue(spokeDao != address(0));
        assertTrue(spokeSecurityCouncil != address(0));
    }

    function testDeployScriptHub() public {
        ChainsData.ChainData memory chainData = ChainsData.getChainData(ChainsData.CHAIN_ID_ETHEREUM);
        vm.createSelectFork({urlOrAlias: chainData.foundryAlias});

        vm.setEnv("HUB_CORE_PARAMS_FILENAME", chainData.constantsFilename);
        vm.setEnv("HUB_CORE_OUTPUT_FILENAME", chainData.constantsFilename);
        vm.setEnv("HUB_MACHINE_PARAMS_FILENAME", chainData.constantsFilename);
        vm.setEnv("HUB_MACHINE_OUTPUT_FILENAME", chainData.constantsFilename);

        deployMakinaCoreHub = new DeployMakinaCoreHub();
        deployMakinaCoreHub.run();

        deployHubMachine = new DeployHubMachine();
        deployHubMachine.run();

        HubCore memory hubCoreDeployment = deployMakinaCoreHub.deployment();

        // Check that OracleRegistry is correctly set up
        PriceFeedData[] memory _priceFeedData =
            abi.decode(vm.parseJson(deployMakinaCoreHub.paramsJson(), ".priceFeedData"), (PriceFeedData[]));
        for (uint256 i; i < _priceFeedData.length; i++) {
            (address feed1, address feed2) = hubCoreDeployment.oracleRegistry.getTokenFeedData(_priceFeedData[i].token);
            assertEq(_priceFeedData[i].feed1, feed1);
            assertEq(_priceFeedData[i].feed2, feed2);
        }

        // Check that Swapper is correctly set up
        DexAggregatorData[] memory _dexAggregatorsData =
            abi.decode(vm.parseJson(deployMakinaCoreHub.paramsJson(), ".dexAggregatorsTargets"), (DexAggregatorData[]));
        for (uint256 i; i < _dexAggregatorsData.length; i++) {
            (address approvalTarget, address executionTarget) =
                hubCoreDeployment.swapper.dexAggregatorTargets(_dexAggregatorsData[i].aggregatorId);
            assertEq(_dexAggregatorsData[i].approvalTarget, approvalTarget);
            assertEq(_dexAggregatorsData[i].executionTarget, executionTarget);
        }

        // Check that Hub Machine is correctly set up
        DeployHubMachine.MachineInitParamsSorted memory machineInitParams =
            abi.decode(vm.parseJson(deployHubMachine.paramsJson()), (DeployHubMachine.MachineInitParamsSorted));
        IMachine machine = IMachine(deployHubMachine.deployedInstance());
        IHubDualMailbox dualMailbox = IHubDualMailbox(machine.hubCaliberMailbox());
        ICaliber hubCaliber = ICaliber(dualMailbox.caliber());
        IMachineShare shareToken = IMachineShare(machine.shareToken());
        assertTrue(hubCoreDeployment.machineFactory.isMachine(address(machine)));
        assertEq(machine.mechanic(), machineInitParams.initialMechanic);
        assertEq(machine.accountingToken(), machineInitParams.accountingToken);
        assertEq(machine.caliberStaleThreshold(), machineInitParams.initialCaliberStaleThreshold);
        assertEq(machine.shareLimit(), machineInitParams.initialShareLimit);
        assertEq(IAccessManaged(address(machine)).authority(), machineInitParams.initialAuthority);
        assertEq(machine.getSpokeCalibersLength(), 0);
        assertEq(dualMailbox.machine(), address(machine));
        assertEq(hubCaliber.mailbox(), address(dualMailbox));
        assertEq(shareToken.name(), machineInitParams.shareTokenName);
        assertEq(shareToken.symbol(), machineInitParams.shareTokenSymbol);
    }

    function testDeployScriptSpoke() public {
        ChainsData.ChainData memory chainData = ChainsData.getChainData(ChainsData.CHAIN_ID_BASE);
        vm.createSelectFork({urlOrAlias: chainData.foundryAlias});

        vm.setEnv("SPOKE_CORE_PARAMS_FILENAME", chainData.constantsFilename);
        vm.setEnv("SPOKE_CORE_OUTPUT_FILENAME", chainData.constantsFilename);
        vm.setEnv("SPOKE_CALIBER_PARAMS_FILENAME", chainData.constantsFilename);
        vm.setEnv("SPOKE_CALIBER_OUTPUT_FILENAME", chainData.constantsFilename);

        deployMakinaCoreSpoke = new DeployMakinaCoreSpoke();
        deployMakinaCoreSpoke.run();

        deploySpokeCaliber = new DeploySpokeCaliber();
        deploySpokeCaliber.run();

        SpokeCore memory spokeCoreDeployment = deployMakinaCoreSpoke.deployment();

        // Check that OracleRegistry is correctly set up
        PriceFeedData[] memory _priceFeedData =
            abi.decode(vm.parseJson(deployMakinaCoreSpoke.paramsJson(), ".priceFeedData"), (PriceFeedData[]));
        for (uint256 i; i < _priceFeedData.length; i++) {
            (address feed1, address feed2) =
                spokeCoreDeployment.oracleRegistry.getTokenFeedData(_priceFeedData[i].token);
            assertEq(_priceFeedData[i].feed1, feed1);
            assertEq(_priceFeedData[i].feed2, feed2);
        }

        // Check that Swapper is correctly set up
        DexAggregatorData[] memory _dexAggregatorsData = abi.decode(
            vm.parseJson(deployMakinaCoreSpoke.paramsJson(), ".dexAggregatorsTargets"), (DexAggregatorData[])
        );
        for (uint256 i; i < _dexAggregatorsData.length; i++) {
            (address approvalTarget, address executionTarget) =
                spokeCoreDeployment.swapper.dexAggregatorTargets(_dexAggregatorsData[i].aggregatorId);
            assertEq(_dexAggregatorsData[i].approvalTarget, approvalTarget);
            assertEq(_dexAggregatorsData[i].executionTarget, executionTarget);
        }

        // Check that Spoke Caliber is correctly set up
        DeploySpokeCaliber.CaliberInitParamsSorted memory caliberInitParams =
            abi.decode(vm.parseJson(deploySpokeCaliber.paramsJson()), (DeploySpokeCaliber.CaliberInitParamsSorted));
        ICaliber spokeCaliber = ICaliber(deploySpokeCaliber.deployedInstance());
        assertTrue(spokeCoreDeployment.caliberFactory.isCaliber(address(spokeCaliber)));
        assertEq(ICaliberMailbox(spokeCaliber.mailbox()).caliber(), address(spokeCaliber));
        assertEq(spokeCaliber.accountingToken(), caliberInitParams.accountingToken);
        assertEq(spokeCaliber.positionStaleThreshold(), caliberInitParams.initialPositionStaleThreshold);
        assertEq(spokeCaliber.allowedInstrRoot(), caliberInitParams.initialAllowedInstrRoot);
        assertEq(spokeCaliber.timelockDuration(), caliberInitParams.initialTimelockDuration);
        assertEq(spokeCaliber.maxPositionIncreaseLossBps(), caliberInitParams.initialMaxPositionIncreaseLossBps);
        assertEq(spokeCaliber.maxPositionDecreaseLossBps(), caliberInitParams.initialMaxPositionDecreaseLossBps);
        assertEq(spokeCaliber.maxSwapLossBps(), caliberInitParams.initialMaxSwapLossBps);
        assertEq(spokeCaliber.mechanic(), caliberInitParams.initialMechanic);
        assertEq(IAccessManaged(address(spokeCaliber)).authority(), caliberInitParams.initialAuthority);
        assertEq(spokeCaliber.getPositionsLength(), 1);
        assertEq(spokeCaliber.getPositionId(0), caliberInitParams.accountingTokenPosId);
    }
}
