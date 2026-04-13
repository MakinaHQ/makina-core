// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";
import {stdStorage, StdStorage} from "forge-std/StdStorage.sol";

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {ChainsInfo} from "test/utils/ChainsInfo.sol";
import {DeployHubCore} from "script/deployments/DeployHubCore.s.sol";
import {DeployHubMachine} from "script/deployments/DeployHubMachine.s.sol";
import {DeployHubMachineFromPreDeposit} from "script/deployments/DeployHubMachineFromPreDeposit.s.sol";
import {DeployPreDepositVault} from "script/deployments/DeployPreDepositVault.s.sol";
import {DeploySpokeCaliber} from "script/deployments/DeploySpokeCaliber.s.sol";
import {DeploySpokeCore} from "script/deployments/DeploySpokeCore.s.sol";
import {DeployTimelockController} from "script/deployments/DeployTimelockController.s.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";

import {Base_Test} from "../base/Base.t.sol";

contract Deploy_Scripts_Test is Base_Test {
    using stdJson for string;
    using stdStorage for StdStorage;

    // Scripts to test
    DeployHubCore public deployHubCore;
    DeployPreDepositVault public deployPreDepositVault;
    DeployHubMachine public deployHubMachine;
    DeployHubMachineFromPreDeposit public deployMachineFromPreDeposit;
    DeploySpokeCore public deploySpokeCore;
    DeploySpokeCaliber public deploySpokeCaliber;
    DeployTimelockController public deployTimelockController;

    function setUp() public override {
        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_ETHEREUM);

        vm.setEnv("TIMELOCK_CONTROLLER_INPUT_FILENAME", chainInfo.constantsFilename);
        vm.setEnv("TIMELOCK_CONTROLLER_OUTPUT_FILENAME", chainInfo.constantsFilename);

        vm.setEnv("HUB_CORE_INPUT_FILENAME", chainInfo.constantsFilename);
        vm.setEnv("HUB_CORE_OUTPUT_FILENAME", chainInfo.constantsFilename);

        vm.setEnv("HUB_STRAT_INPUT_FILENAME", chainInfo.constantsFilename);
        vm.setEnv("HUB_STRAT_OUTPUT_FILENAME", chainInfo.constantsFilename);

        chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_BASE);

        vm.setEnv("SPOKE_CORE_INPUT_FILENAME", chainInfo.constantsFilename);
        vm.setEnv("SPOKE_CORE_OUTPUT_FILENAME", chainInfo.constantsFilename);

        vm.setEnv("SPOKE_STRAT_INPUT_FILENAME", chainInfo.constantsFilename);
        vm.setEnv("SPOKE_STRAT_OUTPUT_FILENAME", chainInfo.constantsFilename);
    }

    function test_LoadedState() public {
        deployTimelockController = new DeployTimelockController();
        deployHubCore = new DeployHubCore();
        deployHubMachine = new DeployHubMachine();
        deployMachineFromPreDeposit = new DeployHubMachineFromPreDeposit();
        deployPreDepositVault = new DeployPreDepositVault();
        deploySpokeCore = new DeploySpokeCore();
        deploySpokeCaliber = new DeploySpokeCaliber();

        address[] memory initialExecutors =
            vm.parseJsonAddressArray(deployTimelockController.inputJson(), ".initialExecutors");
        assertTrue(initialExecutors.length != 0);

        address hubSuperAdmin = vm.parseJsonAddress(deployHubCore.inputJson(), ".superAdminRoleGrant.account");
        assertTrue(hubSuperAdmin != address(0));

        address machineMechanic =
            vm.parseJsonAddress(deployHubMachine.inputJson(), ".makinaGovernableInitParams.initialMechanic");
        assertTrue(machineMechanic != address(0));

        machineMechanic =
            vm.parseJsonAddress(deployMachineFromPreDeposit.inputJson(), ".makinaGovernableInitParams.initialMechanic");
        assertTrue(machineMechanic != address(0));

        address pdvRiskManager =
            vm.parseJsonAddress(deployPreDepositVault.inputJson(), ".preDepositVaultInitParams.initialRiskManager");
        assertTrue(pdvRiskManager != address(0));

        address spokeSuperAdmin = vm.parseJsonAddress(deploySpokeCore.inputJson(), ".superAdminRoleGrant.account");
        assertTrue(spokeSuperAdmin != address(0));

        address caliberMechanic =
            vm.parseJsonAddress(deploySpokeCaliber.inputJson(), ".makinaGovernableInitParams.initialMechanic");
        assertTrue(caliberMechanic != address(0));
    }

    function testScript_DeployHubCore() public {
        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_ETHEREUM);
        vm.createSelectFork({urlOrAlias: chainInfo.foundryAlias});

        // Core deployment
        deployHubCore = new DeployHubCore();
        deployHubCore.run();

        (HubCore memory hubCoreDeployment, UpgradeableBeacon[] memory bridgeAdapterBeaconsDeployment) =
            deployHubCore.deployment();

        // Check that OracleRegistry is correctly set up
        PriceFeedRoute[] memory _priceFeedRoutes =
            abi.decode(vm.parseJson(deployHubCore.inputJson(), ".priceFeedRoutes"), (PriceFeedRoute[]));
        for (uint256 i; i < _priceFeedRoutes.length; ++i) {
            (address feed1, address feed2) = hubCoreDeployment.oracleRegistry.getFeedRoute(_priceFeedRoutes[i].token);
            assertEq(_priceFeedRoutes[i].feed1, feed1);
            assertEq(_priceFeedRoutes[i].feed2, feed2);
        }

        // Check that TokenRegistry is correctly set up
        TokenToRegister[] memory tokensToRegister =
            abi.decode(vm.parseJson(deployHubCore.inputJson(), ".foreignTokens"), (TokenToRegister[]));
        for (uint256 i; i < tokensToRegister.length; ++i) {
            assertEq(
                hubCoreDeployment.tokenRegistry
                    .getForeignToken(tokensToRegister[i].localToken, tokensToRegister[i].foreignEvmChainId),
                tokensToRegister[i].foreignToken
            );
            assertEq(
                hubCoreDeployment.tokenRegistry
                    .getLocalToken(tokensToRegister[i].foreignToken, tokensToRegister[i].foreignEvmChainId),
                tokensToRegister[i].localToken
            );
        }

        // Check that SwapModule is correctly set up
        SwapperData[] memory _swappersData =
            abi.decode(vm.parseJson(deployHubCore.inputJson(), ".swappersTargets"), (SwapperData[]));
        for (uint256 i; i < _swappersData.length; ++i) {
            (address approvalTarget, address executionTarget) =
                hubCoreDeployment.swapModule.getSwapperTargets(_swappersData[i].swapperId);
            assertEq(_swappersData[i].approvalTarget, approvalTarget);
            assertEq(_swappersData[i].executionTarget, executionTarget);
        }

        // Check that ChainRegistry is correctly set up
        uint256[] memory supportedChains = vm.parseJsonUintArray(deployHubCore.inputJson(), ".supportedChains");
        for (uint256 i; i < supportedChains.length; ++i) {
            assertEq(
                hubCoreDeployment.chainRegistry.evmToWhChainId(supportedChains[i]),
                ChainsInfo.getChainInfo(supportedChains[i]).wormholeChainId
            );
        }

        // Check that BridgeAdapterBeacons are correctly set up
        BridgeData[] memory _bridgesData =
            abi.decode(vm.parseJson(deployHubCore.inputJson(), ".bridgesTargets"), (BridgeData[]));
        for (uint256 i; i < _bridgesData.length; ++i) {
            IBridgeAdapter implementation = IBridgeAdapter(bridgeAdapterBeaconsDeployment[i].implementation());
            address approvalTarget = implementation.approvalTarget();
            address executionTarget = implementation.executionTarget();
            address receiveSource = implementation.receiveSource();
            assertEq(_bridgesData[i].approvalTarget, approvalTarget);
            assertEq(_bridgesData[i].executionTarget, executionTarget);
            assertEq(_bridgesData[i].receiveSource, receiveSource);
        }

        AMRoleGrant[] memory _otherRoleGrants =
            abi.decode(vm.parseJson(deployHubCore.inputJson(), ".otherRoleGrants"), (AMRoleGrant[]));
        for (uint256 i; i < _otherRoleGrants.length; ++i) {
            (bool isMember, uint32 executionDelay) =
                hubCoreDeployment.accessManager.hasRole(_otherRoleGrants[i].roleId, _otherRoleGrants[i].account);
            assertTrue(isMember);
            assertEq(executionDelay, _otherRoleGrants[i].executionDelay);
        }
    }

    function testScript_DeployHubMachine() public {
        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_ETHEREUM);
        vm.createSelectFork({urlOrAlias: chainInfo.foundryAlias});

        // Core deployment
        deployHubCore = new DeployHubCore();
        deployHubCore.setSkipAMSetup(true);
        deployHubCore.run();

        (HubCore memory hubCoreDeployment,) = deployHubCore.deployment();

        // Machine deployment
        deployHubMachine = new DeployHubMachine();
        deployHubMachine.run();

        // Check that Hub Machine is correctly set up
        IMachine.MachineInitParams memory mParams =
            abi.decode(vm.parseJson(deployHubMachine.inputJson(), ".machineInitParams"), (IMachine.MachineInitParams));
        ICaliber.CaliberInitParams memory cParams =
            abi.decode(vm.parseJson(deployHubMachine.inputJson(), ".caliberInitParams"), (ICaliber.CaliberInitParams));
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams = abi.decode(
            vm.parseJson(deployHubMachine.inputJson(), ".makinaGovernableInitParams"),
            (IMakinaGovernable.MakinaGovernableInitParams)
        );
        address accountingToken = vm.parseJsonAddress(deployHubMachine.inputJson(), ".accountingToken");
        string memory shareTokenName = vm.parseJsonString(deployHubMachine.inputJson(), ".shareTokenName");
        string memory shareTokenSymbol = vm.parseJsonString(deployHubMachine.inputJson(), ".shareTokenSymbol");
        IMachine machine = IMachine(deployHubMachine.deployedInstance());
        ICaliber hubCaliber = ICaliber(machine.hubCaliber());
        IMachineShare shareToken = IMachineShare(machine.shareToken());

        assertTrue(hubCoreDeployment.hubCoreFactory.isMachine(address(machine)));
        assertTrue(hubCoreDeployment.hubCoreFactory.isCaliber(address(hubCaliber)));
        assertEq(machine.depositor(), mParams.initialDepositor);
        assertEq(machine.redeemer(), mParams.initialRedeemer);
        assertEq(machine.accountingToken(), accountingToken);
        assertEq(machine.caliberStaleThreshold(), mParams.initialCaliberStaleThreshold);
        assertEq(machine.shareLimit(), mParams.initialShareLimit);
        assertEq(machine.maxFixedFeeAccrualRate(), mParams.initialMaxFixedFeeAccrualRate);
        assertEq(machine.maxPerfFeeAccrualRate(), mParams.initialMaxPerfFeeAccrualRate);
        assertEq(machine.maxSharePriceChangeRate(), mParams.initialMaxSharePriceChangeRate);

        assertEq(machine.mechanic(), mgParams.initialMechanic);
        assertEq(machine.securityCouncil(), mgParams.initialSecurityCouncil);
        assertEq(machine.riskManager(), mgParams.initialRiskManager);
        assertEq(machine.riskManagerTimelock(), mgParams.initialRiskManagerTimelock);
        assertEq(IAccessManaged(address(machine)).authority(), mgParams.initialAuthority);
        assertEq(machine.restrictedAccountingMode(), mgParams.initialRestrictedAccountingMode);

        assertEq(hubCaliber.hubMachineEndpoint(), address(machine));
        assertEq(hubCaliber.accountingToken(), accountingToken);
        assertEq(hubCaliber.positionStaleThreshold(), cParams.initialPositionStaleThreshold);
        assertEq(hubCaliber.allowedInstrRoot(), cParams.initialAllowedInstrRoot);
        assertEq(hubCaliber.timelockDuration(), cParams.initialTimelockDuration);
        assertEq(hubCaliber.maxPositionIncreaseLossBps(), cParams.initialMaxPositionIncreaseLossBps);
        assertEq(hubCaliber.maxPositionDecreaseLossBps(), cParams.initialMaxPositionDecreaseLossBps);
        assertEq(hubCaliber.maxSwapLossBps(), cParams.initialMaxSwapLossBps);
        assertEq(hubCaliber.cooldownDuration(), cParams.initialCooldownDuration);

        assertEq(machine.getSpokeCalibersLength(), 0);
        assertEq(shareToken.name(), shareTokenName);
        assertEq(shareToken.symbol(), shareTokenSymbol);
    }

    function testScript_DeployPreDepositVault() public {
        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_ETHEREUM);
        vm.createSelectFork({urlOrAlias: chainInfo.foundryAlias});

        // Core deployment
        deployHubCore = new DeployHubCore();
        deployHubCore.setSkipAMSetup(true);
        deployHubCore.run();

        (HubCore memory hubCoreDeployment,) = deployHubCore.deployment();

        // PreDeposit Vault deployment
        deployPreDepositVault = new DeployPreDepositVault();
        deployPreDepositVault.run();

        // Check that PreDepositVault is correctly set up
        IPreDepositVault.PreDepositVaultInitParams memory pdvParams = abi.decode(
            vm.parseJson(deployPreDepositVault.inputJson(), ".preDepositVaultInitParams"),
            (IPreDepositVault.PreDepositVaultInitParams)
        );
        address depositToken = vm.parseJsonAddress(deployPreDepositVault.inputJson(), ".depositToken");
        address accountingToken = vm.parseJsonAddress(deployPreDepositVault.inputJson(), ".accountingToken");
        string memory shareTokenName = vm.parseJsonString(deployPreDepositVault.inputJson(), ".shareTokenName");
        string memory shareTokenSymbol = vm.parseJsonString(deployPreDepositVault.inputJson(), ".shareTokenSymbol");

        IPreDepositVault preDepositVault = IPreDepositVault(deployPreDepositVault.deployedInstance());
        IMachineShare shareToken = IMachineShare(preDepositVault.shareToken());

        assertTrue(hubCoreDeployment.hubCoreFactory.isPreDepositVault(address(preDepositVault)));
        assertEq(preDepositVault.shareLimit(), pdvParams.initialShareLimit);
        assertEq(preDepositVault.whitelistMode(), pdvParams.initialWhitelistMode);
        assertEq(preDepositVault.riskManager(), pdvParams.initialRiskManager);
        assertEq(preDepositVault.depositToken(), depositToken);
        assertEq(preDepositVault.accountingToken(), accountingToken);
        assertEq(IAccessManaged(address(preDepositVault)).authority(), pdvParams.initialAuthority);

        assertEq(shareToken.name(), shareTokenName);
        assertEq(shareToken.symbol(), shareTokenSymbol);
    }

    function testScrip_DeployHubMachineFromPreDeposit() public {
        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_ETHEREUM);
        vm.createSelectFork({urlOrAlias: chainInfo.foundryAlias});

        // Core deployment
        deployHubCore = new DeployHubCore();
        deployHubCore.setSkipAMSetup(true);
        deployHubCore.run();

        (HubCore memory hubCoreDeployment,) = deployHubCore.deployment();

        // PreDeposit Vault deployment
        deployPreDepositVault = new DeployPreDepositVault();
        deployPreDepositVault.run();

        // PreDeposit Vault migration to Machine
        deployMachineFromPreDeposit = new DeployHubMachineFromPreDeposit();
        stdstore.target(address(deployMachineFromPreDeposit)).sig("preDepositVault()")
            .checked_write(deployPreDepositVault.deployedInstance());
        deployMachineFromPreDeposit.run();

        // Check that Hub Machine is correctly set up
        IMachine.MachineInitParams memory mParams = abi.decode(
            vm.parseJson(deployMachineFromPreDeposit.inputJson(), ".machineInitParams"), (IMachine.MachineInitParams)
        );
        ICaliber.CaliberInitParams memory cParams = abi.decode(
            vm.parseJson(deployMachineFromPreDeposit.inputJson(), ".caliberInitParams"), (ICaliber.CaliberInitParams)
        );
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams = abi.decode(
            vm.parseJson(deployMachineFromPreDeposit.inputJson(), ".makinaGovernableInitParams"),
            (IMakinaGovernable.MakinaGovernableInitParams)
        );
        address accountingToken = vm.parseJsonAddress(deployPreDepositVault.inputJson(), ".accountingToken");
        string memory shareTokenName = vm.parseJsonString(deployPreDepositVault.inputJson(), ".shareTokenName");
        string memory shareTokenSymbol = vm.parseJsonString(deployPreDepositVault.inputJson(), ".shareTokenSymbol");

        IMachine machine = IMachine(deployMachineFromPreDeposit.deployedInstance());
        ICaliber hubCaliber = ICaliber(machine.hubCaliber());
        IMachineShare shareToken = IMachineShare(machine.shareToken());

        assertTrue(hubCoreDeployment.hubCoreFactory.isMachine(address(machine)));
        assertTrue(hubCoreDeployment.hubCoreFactory.isCaliber(address(hubCaliber)));
        assertEq(machine.depositor(), mParams.initialDepositor);
        assertEq(machine.redeemer(), mParams.initialRedeemer);
        assertEq(machine.accountingToken(), accountingToken);
        assertEq(machine.caliberStaleThreshold(), mParams.initialCaliberStaleThreshold);
        assertEq(machine.shareLimit(), mParams.initialShareLimit);
        assertEq(machine.accountingToken(), accountingToken);
        assertTrue(machine.isIdleToken(accountingToken));
        assertEq(machine.getIdleTokensLength(), 1);
        assertEq(machine.getIdleToken(0), accountingToken);
        assertEq(machine.maxFixedFeeAccrualRate(), mParams.initialMaxFixedFeeAccrualRate);
        assertEq(machine.maxPerfFeeAccrualRate(), mParams.initialMaxPerfFeeAccrualRate);
        assertEq(machine.maxSharePriceChangeRate(), mParams.initialMaxSharePriceChangeRate);

        assertEq(machine.mechanic(), mgParams.initialMechanic);
        assertEq(machine.securityCouncil(), mgParams.initialSecurityCouncil);
        assertEq(machine.riskManager(), mgParams.initialRiskManager);
        assertEq(machine.riskManagerTimelock(), mgParams.initialRiskManagerTimelock);
        assertEq(IAccessManaged(address(machine)).authority(), mgParams.initialAuthority);
        assertEq(machine.restrictedAccountingMode(), mgParams.initialRestrictedAccountingMode);

        assertEq(hubCaliber.hubMachineEndpoint(), address(machine));
        assertEq(hubCaliber.accountingToken(), accountingToken);
        assertEq(hubCaliber.positionStaleThreshold(), cParams.initialPositionStaleThreshold);
        assertEq(hubCaliber.allowedInstrRoot(), cParams.initialAllowedInstrRoot);
        assertEq(hubCaliber.timelockDuration(), cParams.initialTimelockDuration);
        assertEq(hubCaliber.maxPositionIncreaseLossBps(), cParams.initialMaxPositionIncreaseLossBps);
        assertEq(hubCaliber.maxPositionDecreaseLossBps(), cParams.initialMaxPositionDecreaseLossBps);
        assertEq(hubCaliber.maxSwapLossBps(), cParams.initialMaxSwapLossBps);
        assertEq(hubCaliber.cooldownDuration(), cParams.initialCooldownDuration);

        assertEq(machine.getSpokeCalibersLength(), 0);
        assertEq(shareToken.name(), shareTokenName);
        assertEq(shareToken.symbol(), shareTokenSymbol);
    }

    function testScript_DeploySpokeCore() public {
        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_BASE);
        vm.createSelectFork({urlOrAlias: chainInfo.foundryAlias});

        // Spoke Core deployment
        deploySpokeCore = new DeploySpokeCore();
        deploySpokeCore.run();

        (SpokeCore memory spokeCoreDeployment, UpgradeableBeacon[] memory bridgeAdapterBeaconsDeployment) =
            deploySpokeCore.deployment();

        // Check that OracleRegistry is correctly set up
        PriceFeedRoute[] memory _priceFeedRoutes =
            abi.decode(vm.parseJson(deploySpokeCore.inputJson(), ".priceFeedRoutes"), (PriceFeedRoute[]));
        for (uint256 i; i < _priceFeedRoutes.length; ++i) {
            (address feed1, address feed2) = spokeCoreDeployment.oracleRegistry.getFeedRoute(_priceFeedRoutes[i].token);
            assertEq(_priceFeedRoutes[i].feed1, feed1);
            assertEq(_priceFeedRoutes[i].feed2, feed2);
        }

        // Check that TokenRegistry is correctly set up
        TokenToRegister[] memory tokensToRegister =
            abi.decode(vm.parseJson(deploySpokeCore.inputJson(), ".foreignTokens"), (TokenToRegister[]));
        for (uint256 i; i < tokensToRegister.length; ++i) {
            assertEq(
                spokeCoreDeployment.tokenRegistry
                    .getForeignToken(tokensToRegister[i].localToken, tokensToRegister[i].foreignEvmChainId),
                tokensToRegister[i].foreignToken
            );
            assertEq(
                spokeCoreDeployment.tokenRegistry
                    .getLocalToken(tokensToRegister[i].foreignToken, tokensToRegister[i].foreignEvmChainId),
                tokensToRegister[i].localToken
            );
        }

        // Check that SwapModule is correctly set up
        SwapperData[] memory _swappersData =
            abi.decode(vm.parseJson(deploySpokeCore.inputJson(), ".swappersTargets"), (SwapperData[]));
        for (uint256 i; i < _swappersData.length; ++i) {
            (address approvalTarget, address executionTarget) =
                spokeCoreDeployment.swapModule.getSwapperTargets(_swappersData[i].swapperId);
            assertEq(_swappersData[i].approvalTarget, approvalTarget);
            assertEq(_swappersData[i].executionTarget, executionTarget);
        }

        // Check that BridgeAdapterBeacons are correctly set up
        BridgeData[] memory _bridgesData =
            abi.decode(vm.parseJson(deploySpokeCore.inputJson(), ".bridgesTargets"), (BridgeData[]));
        for (uint256 i; i < _bridgesData.length; ++i) {
            IBridgeAdapter implementation = IBridgeAdapter(bridgeAdapterBeaconsDeployment[i].implementation());
            address approvalTarget = implementation.approvalTarget();
            address executionTarget = implementation.executionTarget();
            address receiveSource = implementation.receiveSource();
            assertEq(_bridgesData[i].approvalTarget, approvalTarget);
            assertEq(_bridgesData[i].executionTarget, executionTarget);
            assertEq(_bridgesData[i].receiveSource, receiveSource);
        }

        AMRoleGrant[] memory _otherRoleGrants =
            abi.decode(vm.parseJson(deploySpokeCore.inputJson(), ".otherRoleGrants"), (AMRoleGrant[]));
        for (uint256 i; i < _otherRoleGrants.length; ++i) {
            (bool isMember, uint32 executionDelay) =
                spokeCoreDeployment.accessManager.hasRole(_otherRoleGrants[i].roleId, _otherRoleGrants[i].account);
            assertTrue(isMember);
            assertEq(executionDelay, _otherRoleGrants[i].executionDelay);
        }
    }

    function testScript_DeploySpokeCaliber() public {
        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_BASE);
        vm.createSelectFork({urlOrAlias: chainInfo.foundryAlias});

        // Spoke Core deployment
        deploySpokeCore = new DeploySpokeCore();
        deploySpokeCore.setSkipAMSetup(true);
        deploySpokeCore.run();

        (SpokeCore memory spokeCoreDeployment,) = deploySpokeCore.deployment();

        // Caliber deployment
        deploySpokeCaliber = new DeploySpokeCaliber();
        deploySpokeCaliber.run();

        // Check that Spoke Caliber is correctly set up
        ICaliber.CaliberInitParams memory cParams = abi.decode(
            vm.parseJson(deploySpokeCaliber.inputJson(), ".caliberInitParams"), (ICaliber.CaliberInitParams)
        );
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams = abi.decode(
            vm.parseJson(deploySpokeCaliber.inputJson(), ".makinaGovernableInitParams"),
            (IMakinaGovernable.MakinaGovernableInitParams)
        );
        address accountingToken = vm.parseJsonAddress(deploySpokeCaliber.inputJson(), ".accountingToken");
        ICaliber spokeCaliber = ICaliber(deploySpokeCaliber.deployedInstance());

        assertTrue(spokeCoreDeployment.spokeCoreFactory.isCaliber(address(spokeCaliber)));
        assertTrue(spokeCoreDeployment.spokeCoreFactory.isCaliberMailbox(spokeCaliber.hubMachineEndpoint()));

        assertEq(spokeCaliber.accountingToken(), accountingToken);
        assertEq(spokeCaliber.positionStaleThreshold(), cParams.initialPositionStaleThreshold);
        assertEq(spokeCaliber.allowedInstrRoot(), cParams.initialAllowedInstrRoot);
        assertEq(spokeCaliber.timelockDuration(), cParams.initialTimelockDuration);
        assertEq(spokeCaliber.maxPositionIncreaseLossBps(), cParams.initialMaxPositionIncreaseLossBps);
        assertEq(spokeCaliber.maxPositionDecreaseLossBps(), cParams.initialMaxPositionDecreaseLossBps);
        assertEq(spokeCaliber.maxSwapLossBps(), cParams.initialMaxSwapLossBps);
        assertEq(spokeCaliber.cooldownDuration(), cParams.initialCooldownDuration);

        ICaliberMailbox mailbox = ICaliberMailbox(spokeCaliber.hubMachineEndpoint());
        assertEq(ICaliberMailbox(mailbox).caliber(), address(spokeCaliber));

        assertEq(mailbox.mechanic(), mgParams.initialMechanic);
        assertEq(mailbox.securityCouncil(), mgParams.initialSecurityCouncil);
        assertEq(mailbox.riskManager(), mgParams.initialRiskManager);
        assertEq(mailbox.riskManagerTimelock(), mgParams.initialRiskManagerTimelock);
        assertEq(IAccessManaged(address(mailbox)).authority(), mgParams.initialAuthority);
        assertEq(IAccessManaged(address(spokeCaliber)).authority(), mgParams.initialAuthority);
        assertEq(mailbox.restrictedAccountingMode(), mgParams.initialRestrictedAccountingMode);

        assertEq(spokeCaliber.getPositionsLength(), 0);
        assertEq(spokeCaliber.getBaseTokensLength(), 1);
    }

    function testScript_DeployTimelockController() public {
        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(ChainsInfo.CHAIN_ID_ETHEREUM);
        vm.createSelectFork({urlOrAlias: chainInfo.foundryAlias});

        // Timelock Controller deployment
        deployTimelockController = new DeployTimelockController();
        deployTimelockController.run();

        // Check that Timelock Controller is correctly set up
        uint256 initialMinDelay = vm.parseJsonUint(deployTimelockController.inputJson(), ".initialMinDelay");
        address[] memory initialProposers =
            vm.parseJsonAddressArray(deployTimelockController.inputJson(), ".initialProposers");
        address[] memory initialExecutors =
            vm.parseJsonAddressArray(deployTimelockController.inputJson(), ".initialExecutors");
        address[] memory additionalCancellers =
            vm.parseJsonAddressArray(deployTimelockController.inputJson(), ".additionalCancellers");

        TimelockController timelockController = TimelockController(payable(deployTimelockController.deployedInstance()));
        for (uint256 i; i < initialProposers.length; ++i) {
            assertTrue(timelockController.hasRole(timelockController.PROPOSER_ROLE(), initialProposers[i]));
            assertTrue(timelockController.hasRole(timelockController.CANCELLER_ROLE(), initialProposers[i]));
        }
        for (uint256 i; i < initialExecutors.length; ++i) {
            assertTrue(timelockController.hasRole(timelockController.EXECUTOR_ROLE(), initialExecutors[i]));
        }
        for (uint256 i; i < additionalCancellers.length; ++i) {
            assertTrue(timelockController.hasRole(timelockController.CANCELLER_ROLE(), additionalCancellers[i]));
        }
        assertEq(timelockController.getMinDelay(), initialMinDelay);
    }
}
