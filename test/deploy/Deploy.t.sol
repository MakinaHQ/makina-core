// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

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
import {IHubCoreFactory} from "src/interfaces/IHubCoreFactory.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";

import {MockCreForwarder} from "../mocks/MockCreForwarder.sol";
import {Base} from "../base/Base.sol";
import {Base_Test} from "../base/Base.t.sol";

/// @dev Exposes the Base AccessManager setup externally, so that its reverts can be asserted.
contract BaseHarness is Base {
    function setupRoles(
        AccessManagerUpgradeable accessManager,
        AMRoleGrant calldata superAdminRoleGrant,
        AMRoleGrant[] calldata otherRoleGrants,
        address coreFactory,
        address deployer
    ) external {
        setupAccessManagerRoles(accessManager, superAdminRoleGrant, otherRoleGrants, coreFactory, deployer);
    }
}

contract Deploy_Scripts_Test is Base_Test {
    using stdJson for string;

    // Scripts to test
    DeployHubCore public deployHubCore;
    DeployPreDepositVault public deployPreDepositVault;
    DeployHubMachine public deployHubMachine;
    DeployHubMachineFromPreDeposit public deployMachineFromPreDeposit;
    DeploySpokeCore public deploySpokeCore;
    DeploySpokeCaliber public deploySpokeCaliber;
    DeployTimelockController public deployTimelockController;

    function test_LoadedState() public {
        string memory hubFilename = _hubTestFilename();
        string memory spokeFilename = _spokeTestFilename();

        deployTimelockController = new DeployTimelockController();
        deployTimelockController.setFilenames(hubFilename, "");

        deployHubCore = new DeployHubCore();
        deployHubCore.setFilenames(hubFilename, "");

        // no factory needed here, only the input files are inspected
        deployHubMachine = new DeployHubMachine();
        deployHubMachine.setParams(address(0), hubFilename, "");

        deployMachineFromPreDeposit = new DeployHubMachineFromPreDeposit();
        deployMachineFromPreDeposit.setParams(address(0), hubFilename, "");

        deployPreDepositVault = new DeployPreDepositVault();
        deployPreDepositVault.setParams(address(0), hubFilename, "");

        deploySpokeCore = new DeploySpokeCore();
        deploySpokeCore.setFilenames(spokeFilename, "");

        deploySpokeCaliber = new DeploySpokeCaliber();
        deploySpokeCaliber.setParams(address(0), spokeFilename, "");

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
        vm.createSelectFork({urlOrAlias: getChain(ETHEREUM_CHAIN_ID).chainAlias});

        // Core deployment
        deployHubCore = new DeployHubCore();
        deployHubCore.setFilenames(_hubTestFilename(), "");
        deployHubCore.run();

        (HubCore memory hubCoreDeployment, UpgradeableBeacon[] memory bridgeAdapterBeaconsDeployment) =
            deployHubCore.deployment();

        // Check that OracleRegistry is correctly set up
        PriceFeedRoute[] memory _priceFeedRoutes = parsePriceFeedRoutes(deployHubCore.inputJson(), ".priceFeedRoutes");
        for (uint256 i; i < _priceFeedRoutes.length; ++i) {
            (address feed1, address feed2) = hubCoreDeployment.oracleRegistry.getFeedRoute(_priceFeedRoutes[i].token);
            assertEq(_priceFeedRoutes[i].feed1, feed1);
            assertEq(_priceFeedRoutes[i].feed2, feed2);
        }

        // Check that TokenRegistry is correctly set up
        TokenToRegister[] memory tokensToRegister = parseTokensToRegister(deployHubCore.inputJson(), ".foreignTokens");
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
        SwapperData[] memory _swappersData = parseSwappersData(deployHubCore.inputJson(), ".swappersTargets");
        for (uint256 i; i < _swappersData.length; ++i) {
            (address approvalTarget, address executionTarget) =
                hubCoreDeployment.swapModule.getSwapperTargets(_swappersData[i].swapperId);
            assertEq(_swappersData[i].approvalTarget, approvalTarget);
            assertEq(_swappersData[i].executionTarget, executionTarget);
        }

        // Check that BridgeAdapterBeacons are correctly set up
        BridgeData[] memory _bridgesData = parseBridgesData(deployHubCore.inputJson(), ".bridgesTargets");
        for (uint256 i; i < _bridgesData.length; ++i) {
            IBridgeAdapter implementation = IBridgeAdapter(bridgeAdapterBeaconsDeployment[i].implementation());
            address approvalTarget = implementation.approvalTarget();
            address executionTarget = implementation.executionTarget();
            address receiveSource = implementation.receiveSource();
            assertEq(_bridgesData[i].approvalTarget, approvalTarget);
            assertEq(_bridgesData[i].executionTarget, executionTarget);
            assertEq(_bridgesData[i].receiveSource, receiveSource);
        }

        AMRoleGrant[] memory _otherRoleGrants = parseAMRoleGrants(deployHubCore.inputJson(), ".otherRoleGrants");
        for (uint256 i; i < _otherRoleGrants.length; ++i) {
            (bool isMember, uint32 executionDelay) =
                hubCoreDeployment.accessManager.hasRole(_otherRoleGrants[i].roleId, _otherRoleGrants[i].account);
            assertTrue(isMember);
            assertEq(executionDelay, _otherRoleGrants[i].executionDelay);
        }

        // Check that the AccessManager owns its own ProxyAdmin
        _assertAccessManagerOwnsItsProxyAdmin(hubCoreDeployment.accessManager);
    }

    function testScript_DeployHubCore_FromEnv_SkipAMSetup() public {
        vm.createSelectFork({urlOrAlias: getChain(ETHEREUM_CHAIN_ID).chainAlias});

        string memory scratchFilename = _hubScratchFilename();
        vm.setEnv("HUB_CORE_INPUT_FILENAME", _hubTestFilename());
        vm.setEnv("HUB_CORE_OUTPUT_FILENAME", scratchFilename);
        vm.setEnv("SKIP_AM_SETUP", "true");

        // Core deployment, with all params resolved from the env
        deployHubCore = new DeployHubCore();
        deployHubCore.run();

        (HubCore memory hubCoreDeployment,) = deployHubCore.deployment();

        // Check that the AM setup was skipped: the super admin was not granted the ADMIN_ROLE
        assertTrue(deployHubCore.skipAMSetup());
        address superAdmin = vm.parseJsonAddress(deployHubCore.inputJson(), ".superAdminRoleGrant.account");
        (bool isMember,) =
            hubCoreDeployment.accessManager.hasRole(hubCoreDeployment.accessManager.ADMIN_ROLE(), superAdmin);
        assertFalse(isMember);

        // Check that the output file is written
        string memory outputJson = vm.readFile(deployHubCore.outputPath());
        assertEq(vm.parseJsonAddress(outputJson, ".AccessManager"), address(hubCoreDeployment.accessManager));
        assertEq(vm.parseJsonAddress(outputJson, ".HubCoreFactory"), address(hubCoreDeployment.hubCoreFactory));
        vm.removeFile(deployHubCore.outputPath());
    }

    function testScript_DeployHubMachine() public {
        vm.createSelectFork({urlOrAlias: getChain(ETHEREUM_CHAIN_ID).chainAlias});

        // Core deployment
        deployHubCore = new DeployHubCore();
        deployHubCore.setFilenames(_hubTestFilename(), "");
        deployHubCore.setSkipAMSetup(true);
        deployHubCore.run();

        (HubCore memory hubCoreDeployment,) = deployHubCore.deployment();

        // Machine deployment
        deployHubMachine = new DeployHubMachine();
        deployHubMachine.setParams(address(hubCoreDeployment.hubCoreFactory), _hubTestFilename(), "");
        deployHubMachine.run();

        // Check that the AccessManager owns its own ProxyAdmin even when the AM setup is skipped
        _assertAccessManagerOwnsItsProxyAdmin(hubCoreDeployment.accessManager);

        // Check that Hub Machine is correctly set up
        IMachine.MachineInitParams memory mParams =
            parseMachineInitParams(deployHubMachine.inputJson(), ".machineInitParams");
        ICaliber.CaliberInitParams memory cParams =
            parseCaliberInitParams(deployHubMachine.inputJson(), ".caliberInitParams");
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams =
            parseMakinaGovernableInitParams(deployHubMachine.inputJson(), ".makinaGovernableInitParams");
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

    function testScript_DeployHubMachine_ViewMode() public {
        vm.createSelectFork({urlOrAlias: getChain(ETHEREUM_CHAIN_ID).chainAlias});

        // Core deployment
        deployHubCore = new DeployHubCore();
        deployHubCore.setFilenames(_hubTestFilename(), "");
        deployHubCore.setSkipAMSetup(true);
        deployHubCore.run();

        (HubCore memory hubCoreDeployment,) = deployHubCore.deployment();

        // View mode: the calldata is logged, the factory is never called and nothing is deployed
        deployHubMachine = new DeployHubMachine();
        deployHubMachine.setParams(address(hubCoreDeployment.hubCoreFactory), _hubTestFilename(), "");
        deployHubMachine.setViewMode(true);

        vm.expectCall(
            address(hubCoreDeployment.hubCoreFactory), abi.encodeWithSelector(IHubCoreFactory.createMachine.selector), 0
        );
        deployHubMachine.run();

        assertEq(deployHubMachine.deployedInstance(), address(0));
    }

    function testScript_DeployPreDepositVault() public {
        vm.createSelectFork({urlOrAlias: getChain(ETHEREUM_CHAIN_ID).chainAlias});

        // Core deployment
        deployHubCore = new DeployHubCore();
        deployHubCore.setFilenames(_hubTestFilename(), "");
        deployHubCore.setSkipAMSetup(true);
        deployHubCore.run();

        (HubCore memory hubCoreDeployment,) = deployHubCore.deployment();

        // PreDeposit Vault deployment, writing the output file
        deployPreDepositVault = new DeployPreDepositVault();
        deployPreDepositVault.setParams(
            address(hubCoreDeployment.hubCoreFactory), _hubTestFilename(), _hubScratchFilename()
        );
        deployPreDepositVault.run();

        // Check that PreDepositVault is correctly set up
        IPreDepositVault.PreDepositVaultInitParams memory pdvParams =
            parsePreDepositVaultInitParams(deployPreDepositVault.inputJson(), ".preDepositVaultInitParams");
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

        // Check that the output file is written
        assertEq(
            vm.parseJsonAddress(vm.readFile(deployPreDepositVault.outputPath()), ".preDepositVault"),
            address(preDepositVault)
        );
        vm.removeFile(deployPreDepositVault.outputPath());
    }

    function testScript_DeployHubMachineFromPreDeposit() public {
        vm.createSelectFork({urlOrAlias: getChain(ETHEREUM_CHAIN_ID).chainAlias});

        // Core deployment
        deployHubCore = new DeployHubCore();
        deployHubCore.setFilenames(_hubTestFilename(), "");
        deployHubCore.setSkipAMSetup(true);
        deployHubCore.run();

        (HubCore memory hubCoreDeployment,) = deployHubCore.deployment();

        // PreDeposit Vault deployment
        deployPreDepositVault = new DeployPreDepositVault();
        deployPreDepositVault.setParams(address(hubCoreDeployment.hubCoreFactory), _hubTestFilename(), "");
        deployPreDepositVault.run();

        // PreDeposit Vault migration to Machine
        deployMachineFromPreDeposit = new DeployHubMachineFromPreDeposit();
        deployMachineFromPreDeposit.setParams(address(hubCoreDeployment.hubCoreFactory), _hubTestFilename(), "");
        deployMachineFromPreDeposit.setPreDepositVault(deployPreDepositVault.deployedInstance());
        deployMachineFromPreDeposit.run();

        // Check that Hub Machine is correctly set up
        IMachine.MachineInitParams memory mParams =
            parseMachineInitParams(deployMachineFromPreDeposit.inputJson(), ".machineInitParams");
        ICaliber.CaliberInitParams memory cParams =
            parseCaliberInitParams(deployMachineFromPreDeposit.inputJson(), ".caliberInitParams");
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams =
            parseMakinaGovernableInitParams(deployMachineFromPreDeposit.inputJson(), ".makinaGovernableInitParams");
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
        vm.createSelectFork({urlOrAlias: getChain(BASE_CHAIN_ID).chainAlias});

        // Spoke Core deployment
        deploySpokeCore = new DeploySpokeCore();
        deploySpokeCore.setFilenames(_spokeTestFilename(), "");
        deploySpokeCore.run();

        (SpokeCore memory spokeCoreDeployment, UpgradeableBeacon[] memory bridgeAdapterBeaconsDeployment) =
            deploySpokeCore.deployment();

        // Check that OracleRegistry is correctly set up
        PriceFeedRoute[] memory _priceFeedRoutes = parsePriceFeedRoutes(deploySpokeCore.inputJson(), ".priceFeedRoutes");
        for (uint256 i; i < _priceFeedRoutes.length; ++i) {
            (address feed1, address feed2) = spokeCoreDeployment.oracleRegistry.getFeedRoute(_priceFeedRoutes[i].token);
            assertEq(_priceFeedRoutes[i].feed1, feed1);
            assertEq(_priceFeedRoutes[i].feed2, feed2);
        }

        // Check that TokenRegistry is correctly set up
        TokenToRegister[] memory tokensToRegister = parseTokensToRegister(deploySpokeCore.inputJson(), ".foreignTokens");
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
        SwapperData[] memory _swappersData = parseSwappersData(deploySpokeCore.inputJson(), ".swappersTargets");
        for (uint256 i; i < _swappersData.length; ++i) {
            (address approvalTarget, address executionTarget) =
                spokeCoreDeployment.swapModule.getSwapperTargets(_swappersData[i].swapperId);
            assertEq(_swappersData[i].approvalTarget, approvalTarget);
            assertEq(_swappersData[i].executionTarget, executionTarget);
        }

        // Check that BridgeAdapterBeacons are correctly set up
        BridgeData[] memory _bridgesData = parseBridgesData(deploySpokeCore.inputJson(), ".bridgesTargets");
        for (uint256 i; i < _bridgesData.length; ++i) {
            IBridgeAdapter implementation = IBridgeAdapter(bridgeAdapterBeaconsDeployment[i].implementation());
            address approvalTarget = implementation.approvalTarget();
            address executionTarget = implementation.executionTarget();
            address receiveSource = implementation.receiveSource();
            assertEq(_bridgesData[i].approvalTarget, approvalTarget);
            assertEq(_bridgesData[i].executionTarget, executionTarget);
            assertEq(_bridgesData[i].receiveSource, receiveSource);
        }

        AMRoleGrant[] memory _otherRoleGrants = parseAMRoleGrants(deploySpokeCore.inputJson(), ".otherRoleGrants");
        for (uint256 i; i < _otherRoleGrants.length; ++i) {
            (bool isMember, uint32 executionDelay) =
                spokeCoreDeployment.accessManager.hasRole(_otherRoleGrants[i].roleId, _otherRoleGrants[i].account);
            assertTrue(isMember);
            assertEq(executionDelay, _otherRoleGrants[i].executionDelay);
        }

        // Check that the AccessManager owns its own ProxyAdmin
        _assertAccessManagerOwnsItsProxyAdmin(spokeCoreDeployment.accessManager);
    }

    function testScript_DeploySpokeCaliber() public {
        vm.createSelectFork({urlOrAlias: getChain(BASE_CHAIN_ID).chainAlias});

        // Spoke Core deployment
        deploySpokeCore = new DeploySpokeCore();
        deploySpokeCore.setFilenames(_spokeTestFilename(), "");
        deploySpokeCore.setSkipAMSetup(true);
        deploySpokeCore.run();

        (SpokeCore memory spokeCoreDeployment,) = deploySpokeCore.deployment();

        // Caliber deployment
        deploySpokeCaliber = new DeploySpokeCaliber();
        deploySpokeCaliber.setParams(address(spokeCoreDeployment.spokeCoreFactory), _spokeTestFilename(), "");
        deploySpokeCaliber.run();

        // Check that the AccessManager owns its own ProxyAdmin even when the AM setup is skipped
        _assertAccessManagerOwnsItsProxyAdmin(spokeCoreDeployment.accessManager);

        // Check that Spoke Caliber is correctly set up
        ICaliber.CaliberInitParams memory cParams =
            parseCaliberInitParams(deploySpokeCaliber.inputJson(), ".caliberInitParams");
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams =
            parseMakinaGovernableInitParams(deploySpokeCaliber.inputJson(), ".makinaGovernableInitParams");
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
        vm.createSelectFork({urlOrAlias: getChain(ETHEREUM_CHAIN_ID).chainAlias});

        // Timelock Controller deployment
        deployTimelockController = new DeployTimelockController();
        deployTimelockController.setFilenames(_hubTestFilename(), "");
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

    function test_SetupAccessManagerRoles_KeepsAdminRoleWhenDeployerIsSuperAdmin() public {
        address admin = address(this);
        // The `deployHubCore` script instance shadows the Base composer, hence the explicit base call
        HubCore memory core = Base.deployHubCore(admin, address(new MockCreForwarder()));

        AMRoleGrant memory superAdminRoleGrant = AMRoleGrant({roleId: 0, account: admin, executionDelay: 0});
        setupAccessManagerRoles(
            core.accessManager, superAdminRoleGrant, new AMRoleGrant[](0), address(core.hubCoreFactory), admin
        );

        (bool isMember,) = core.accessManager.hasRole(core.accessManager.ADMIN_ROLE(), admin);
        assertTrue(isMember);
    }

    function test_SetupAccessManagerRoles_RevertWhen_ZeroRoleGrantAccount() public {
        BaseHarness harness = new BaseHarness();
        HubCore memory core = Base.deployHubCore(address(harness), address(new MockCreForwarder()));

        AMRoleGrant memory superAdminRoleGrant = AMRoleGrant({roleId: 0, account: dao, executionDelay: 0});
        AMRoleGrant[] memory otherRoleGrants = new AMRoleGrant[](1);
        otherRoleGrants[0] = AMRoleGrant({roleId: 1, account: address(0), executionDelay: 0});

        vm.expectRevert(bytes("Base: zero roleGrant account"));
        harness.setupRoles(
            core.accessManager, superAdminRoleGrant, otherRoleGrants, address(core.hubCoreFactory), address(harness)
        );
    }

    function _hubTestFilename() internal returns (string memory) {
        return string.concat(getChain(ETHEREUM_CHAIN_ID).name, "-Test.json");
    }

    function _hubScratchFilename() internal returns (string memory) {
        return string.concat(getChain(ETHEREUM_CHAIN_ID).name, "-Test-Scratch.json");
    }

    function _spokeTestFilename() internal returns (string memory) {
        return string.concat(getChain(BASE_CHAIN_ID).name, "-Test.json");
    }

    function _assertAccessManagerOwnsItsProxyAdmin(AccessManagerUpgradeable accessManager) internal view {
        assertEq(Ownable(getProxyAdmin(address(accessManager))).owner(), address(accessManager));
    }
}
