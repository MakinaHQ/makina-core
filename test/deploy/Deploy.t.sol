// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";
import {stdStorage, StdStorage} from "forge-std/StdStorage.sol";

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ChainsInfo} from "test/utils/ChainsInfo.sol";
import {DeployHubCore} from "script/deployments/DeployHubCore.s.sol";
import {DeployHubMachine} from "script/deployments/DeployHubMachine.s.sol";
import {DeploySpokeCaliber} from "script/deployments/DeploySpokeCaliber.s.sol";
import {DeploySpokeCore} from "script/deployments/DeploySpokeCore.s.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {SortedParams} from "script/deployments/utils/SortedParams.sol";

import {Base_Test} from "../base/Base.t.sol";

contract Deploy_Scripts_Test is Base_Test {
    using stdJson for string;
    using stdStorage for StdStorage;

    // Scripts to test
    DeployHubCore public deployHubCore;
    DeployHubMachine public deployHubMachine;
    DeploySpokeCore public deploySpokeCore;
    DeploySpokeCaliber public deploySpokeCaliber;

    function testLoadedState() public {
        vm.setEnv("HUB_INPUT_FILENAME", ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_ETHEREUM).constantsFilename);
        vm.setEnv("SPOKE_INPUT_FILENAME", ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_BASE).constantsFilename);

        deployHubCore = new DeployHubCore();
        deploySpokeCore = new DeploySpokeCore();

        address hubDao = abi.decode(vm.parseJson(deployHubCore.inputJson(), ".dao"), (address));
        address hubSecurityCouncil = abi.decode(vm.parseJson(deployHubCore.inputJson(), ".securityCouncil"), (address));
        assertTrue(hubDao != address(0));
        assertTrue(hubSecurityCouncil != address(0));

        address spokeDao = abi.decode(vm.parseJson(deploySpokeCore.inputJson(), ".dao"), (address));
        address spokeSecurityCouncil =
            abi.decode(vm.parseJson(deploySpokeCore.inputJson(), ".securityCouncil"), (address));
        assertTrue(spokeDao != address(0));
        assertTrue(spokeSecurityCouncil != address(0));
    }

    function testDeployScriptHub() public {
        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_ETHEREUM);
        vm.createSelectFork({urlOrAlias: chainInfo.foundryAlias});

        vm.setEnv("HUB_INPUT_FILENAME", chainInfo.constantsFilename);
        vm.setEnv("HUB_OUTPUT_FILENAME", chainInfo.constantsFilename);

        deployHubCore = new DeployHubCore();
        deployHubCore.run();

        HubCore memory hubCoreDeployment = deployHubCore.deployment();

        // Check that OracleRegistry is correctly set up
        PriceFeedRoute[] memory _priceFeedRoutes =
            abi.decode(vm.parseJson(deployHubCore.inputJson(), ".priceFeedRoutes"), (PriceFeedRoute[]));
        for (uint256 i; i < _priceFeedRoutes.length; i++) {
            (address feed1, address feed2) = hubCoreDeployment.oracleRegistry.getFeedRoute(_priceFeedRoutes[i].token);
            assertEq(_priceFeedRoutes[i].feed1, feed1);
            assertEq(_priceFeedRoutes[i].feed2, feed2);
        }

        // Check that TokenRegistry is correctly set up
        TokenToRegister[] memory tokensToRegister =
            abi.decode(vm.parseJson(deployHubCore.inputJson(), ".foreignTokens"), (TokenToRegister[]));
        for (uint256 i; i < tokensToRegister.length; i++) {
            assertEq(
                hubCoreDeployment.tokenRegistry.getForeignToken(
                    tokensToRegister[i].localToken, tokensToRegister[i].foreignEvmChainId
                ),
                tokensToRegister[i].foreignToken
            );
            assertEq(
                hubCoreDeployment.tokenRegistry.getLocalToken(
                    tokensToRegister[i].foreignToken, tokensToRegister[i].foreignEvmChainId
                ),
                tokensToRegister[i].localToken
            );
        }

        // Check that SwapModule is correctly set up
        SwapperData[] memory _swappersData =
            abi.decode(vm.parseJson(deployHubCore.inputJson(), ".swappersTargets"), (SwapperData[]));
        for (uint256 i; i < _swappersData.length; i++) {
            (address approvalTarget, address executionTarget) =
                hubCoreDeployment.swapModule.swapperTargets(_swappersData[i].swapperId);
            assertEq(_swappersData[i].approvalTarget, approvalTarget);
            assertEq(_swappersData[i].executionTarget, executionTarget);
        }

        // Check that ChainRegistry is correctly set up
        uint256[] memory supportedChains =
            abi.decode(vm.parseJson(deployHubCore.inputJson(), ".supportedChains"), (uint256[]));
        for (uint256 i; i < supportedChains.length; i++) {
            assertEq(
                hubCoreDeployment.chainRegistry.evmToWhChainId(supportedChains[i]),
                ChainsInfo.getChainInfo(supportedChains[i]).wormholeChainId
            );
        }

        deployHubMachine = new DeployHubMachine();
        deployHubMachine.run();

        // Check that Hub Machine is correctly set up
        SortedParams.MachineInitParamsSorted memory mParams = abi.decode(
            vm.parseJson(deployHubMachine.inputJson(), ".machineInitParams"), (SortedParams.MachineInitParamsSorted)
        );
        SortedParams.CaliberInitParamsSorted memory cParams = abi.decode(
            vm.parseJson(deployHubMachine.inputJson(), ".caliberInitParams"), (SortedParams.CaliberInitParamsSorted)
        );
        SortedParams.MakinaGovernableInitParamsSorted memory mgParams = abi.decode(
            vm.parseJson(deployHubMachine.inputJson(), ".makinaGovernableInitParams"),
            (SortedParams.MakinaGovernableInitParamsSorted)
        );
        string memory shareTokenName =
            abi.decode(vm.parseJson(deployHubMachine.inputJson(), ".shareTokenName"), (string));
        string memory shareTokenSymbol =
            abi.decode(vm.parseJson(deployHubMachine.inputJson(), ".shareTokenSymbol"), (string));
        IMachine machine = IMachine(deployHubMachine.deployedInstance());
        ICaliber hubCaliber = ICaliber(machine.hubCaliber());
        IMachineShare shareToken = IMachineShare(machine.shareToken());

        assertTrue(hubCoreDeployment.machineFactory.isMachine(address(machine)));
        assertTrue(hubCoreDeployment.machineFactory.isCaliber(address(hubCaliber)));
        assertEq(machine.depositor(), mParams.initialDepositor);
        assertEq(machine.redeemer(), mParams.initialRedeemer);
        assertEq(machine.accountingToken(), mParams.accountingToken);
        assertEq(machine.caliberStaleThreshold(), mParams.initialCaliberStaleThreshold);
        assertEq(machine.shareLimit(), mParams.initialShareLimit);

        assertEq(machine.mechanic(), mgParams.initialMechanic);
        assertEq(machine.securityCouncil(), mgParams.initialSecurityCouncil);
        assertEq(machine.riskManager(), mgParams.initialRiskManager);
        assertEq(machine.riskManagerTimelock(), mgParams.initialRiskManagerTimelock);
        assertEq(IAccessManaged(address(machine)).authority(), mgParams.initialAuthority);

        assertEq(hubCaliber.hubMachineEndpoint(), address(machine));
        assertEq(hubCaliber.accountingToken(), cParams.accountingToken);
        assertEq(hubCaliber.positionStaleThreshold(), cParams.initialPositionStaleThreshold);
        assertEq(hubCaliber.allowedInstrRoot(), cParams.initialAllowedInstrRoot);
        assertEq(hubCaliber.timelockDuration(), cParams.initialTimelockDuration);
        assertEq(hubCaliber.maxPositionIncreaseLossBps(), cParams.initialMaxPositionIncreaseLossBps);
        assertEq(hubCaliber.maxPositionDecreaseLossBps(), cParams.initialMaxPositionDecreaseLossBps);
        assertEq(hubCaliber.maxSwapLossBps(), cParams.initialMaxSwapLossBps);
        assertEq(hubCaliber.flashLoanModule(), cParams.initialFlashLoanModule);

        assertEq(machine.getSpokeCalibersLength(), 0);
        assertEq(shareToken.name(), shareTokenName);
        assertEq(shareToken.symbol(), shareTokenSymbol);
    }

    function testDeployScriptSpoke() public {
        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_BASE);
        vm.createSelectFork({urlOrAlias: chainInfo.foundryAlias});

        vm.setEnv("SPOKE_INPUT_FILENAME", chainInfo.constantsFilename);
        vm.setEnv("SPOKE_OUTPUT_FILENAME", chainInfo.constantsFilename);

        deploySpokeCore = new DeploySpokeCore();
        deploySpokeCore.run();

        deploySpokeCaliber = new DeploySpokeCaliber();
        deploySpokeCaliber.run();

        SpokeCore memory spokeCoreDeployment = deploySpokeCore.deployment();

        // Check that OracleRegistry is correctly set up
        PriceFeedRoute[] memory _priceFeedRoutes =
            abi.decode(vm.parseJson(deploySpokeCore.inputJson(), ".priceFeedRoutes"), (PriceFeedRoute[]));
        for (uint256 i; i < _priceFeedRoutes.length; i++) {
            (address feed1, address feed2) = spokeCoreDeployment.oracleRegistry.getFeedRoute(_priceFeedRoutes[i].token);
            assertEq(_priceFeedRoutes[i].feed1, feed1);
            assertEq(_priceFeedRoutes[i].feed2, feed2);
        }

        // Check that TokenRegistry is correctly set up
        TokenToRegister[] memory tokensToRegister =
            abi.decode(vm.parseJson(deploySpokeCore.inputJson(), ".foreignTokens"), (TokenToRegister[]));
        for (uint256 i; i < tokensToRegister.length; i++) {
            assertEq(
                spokeCoreDeployment.tokenRegistry.getForeignToken(
                    tokensToRegister[i].localToken, tokensToRegister[i].foreignEvmChainId
                ),
                tokensToRegister[i].foreignToken
            );
            assertEq(
                spokeCoreDeployment.tokenRegistry.getLocalToken(
                    tokensToRegister[i].foreignToken, tokensToRegister[i].foreignEvmChainId
                ),
                tokensToRegister[i].localToken
            );
        }

        // Check that SwapModule is correctly set up
        SwapperData[] memory _swappersData =
            abi.decode(vm.parseJson(deploySpokeCore.inputJson(), ".swappersTargets"), (SwapperData[]));
        for (uint256 i; i < _swappersData.length; i++) {
            (address approvalTarget, address executionTarget) =
                spokeCoreDeployment.swapModule.swapperTargets(_swappersData[i].swapperId);
            assertEq(_swappersData[i].approvalTarget, approvalTarget);
            assertEq(_swappersData[i].executionTarget, executionTarget);
        }

        // Check that Spoke Caliber is correctly set up
        SortedParams.CaliberInitParamsSorted memory cParams = abi.decode(
            vm.parseJson(deploySpokeCaliber.inputJson(), ".caliberInitParams"), (SortedParams.CaliberInitParamsSorted)
        );
        SortedParams.MakinaGovernableInitParamsSorted memory mgParams = abi.decode(
            vm.parseJson(deploySpokeCaliber.inputJson(), ".makinaGovernableInitParams"),
            (SortedParams.MakinaGovernableInitParamsSorted)
        );
        ICaliber spokeCaliber = ICaliber(deploySpokeCaliber.deployedInstance());

        assertTrue(spokeCoreDeployment.caliberFactory.isCaliber(address(spokeCaliber)));
        assertTrue(spokeCoreDeployment.caliberFactory.isCaliberMailbox(spokeCaliber.hubMachineEndpoint()));
        assertEq(ICaliberMailbox(spokeCaliber.hubMachineEndpoint()).caliber(), address(spokeCaliber));

        assertEq(spokeCaliber.accountingToken(), cParams.accountingToken);
        assertEq(spokeCaliber.positionStaleThreshold(), cParams.initialPositionStaleThreshold);
        assertEq(spokeCaliber.allowedInstrRoot(), cParams.initialAllowedInstrRoot);
        assertEq(spokeCaliber.timelockDuration(), cParams.initialTimelockDuration);
        assertEq(spokeCaliber.maxPositionIncreaseLossBps(), cParams.initialMaxPositionIncreaseLossBps);
        assertEq(spokeCaliber.maxPositionDecreaseLossBps(), cParams.initialMaxPositionDecreaseLossBps);
        assertEq(spokeCaliber.maxSwapLossBps(), cParams.initialMaxSwapLossBps);
        assertEq(spokeCaliber.flashLoanModule(), cParams.initialFlashLoanModule);

        assertEq(spokeCaliber.mechanic(), mgParams.initialMechanic);
        assertEq(spokeCaliber.securityCouncil(), mgParams.initialSecurityCouncil);
        assertEq(spokeCaliber.riskManager(), mgParams.initialRiskManager);
        assertEq(spokeCaliber.riskManagerTimelock(), mgParams.initialRiskManagerTimelock);
        assertEq(IAccessManaged(address(spokeCaliber)).authority(), mgParams.initialAuthority);

        assertEq(IAccessManaged(spokeCaliber.hubMachineEndpoint()).authority(), mgParams.initialAuthority);

        assertEq(spokeCaliber.getPositionsLength(), 0);
        assertEq(spokeCaliber.getBaseTokensLength(), 1);
    }
}
