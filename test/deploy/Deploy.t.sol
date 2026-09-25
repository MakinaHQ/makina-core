// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {DeployForeignHubCore} from "script/deploy/DeployForeignHubCore.s.sol";
import {DeployForeignSpokeCore} from "script/deploy/DeployForeignSpokeCore.s.sol";
import {DeployHubCore} from "script/deploy/DeployHubCore.s.sol";
import {DeployHubMachine} from "script/deploy/DeployHubMachine.s.sol";
import {DeployHubMachineFromPreDeposit} from "script/deploy/DeployHubMachineFromPreDeposit.s.sol";
import {DeployPreDepositVault} from "script/deploy/DeployPreDepositVault.s.sol";
import {DeploySpokeCaliber} from "script/deploy/DeploySpokeCaliber.s.sol";
import {DeploySpokeCore} from "script/deploy/DeploySpokeCore.s.sol";
import {DeployTimelockController} from "script/deploy/DeployTimelockController.s.sol";
import {SetupForeignHubCore} from "script/deploy/SetupForeignHubCore.s.sol";
import {SetupForeignSpokeCore} from "script/deploy/SetupForeignSpokeCore.s.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";
import {IHubCoreFactory} from "src/interfaces/IHubCoreFactory.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMachineShare} from "src/interfaces/IMachineShare.sol";
import {IMakinaContext} from "src/interfaces/IMakinaContext.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {IPreDepositVault} from "src/interfaces/IPreDepositVault.sol";
import {ISpokeCoreFactory} from "src/interfaces/ISpokeCoreFactory.sol";
import {ISwapModule} from "src/interfaces/ISwapModule.sol";
import {Roles} from "src/libraries/Roles.sol";

import {MockCreForwarder} from "../mocks/MockCreForwarder.sol";
import {Constants} from "../utils/Constants.sol";
import {Base} from "../base/Base.sol";

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

contract Deploy_Scripts_Test is Base, Constants, Test {
    DeployHubCore public deployHubCore;
    DeployPreDepositVault public deployPreDepositVault;
    DeployHubMachine public deployHubMachine;
    DeployHubMachineFromPreDeposit public deployMachineFromPreDeposit;
    DeploySpokeCore public deploySpokeCore;
    DeploySpokeCaliber public deploySpokeCaliber;
    DeployTimelockController public deployTimelockController;
    DeployForeignHubCore public deployForeignHubCore;
    DeployForeignSpokeCore public deployForeignSpokeCore;
    SetupForeignHubCore public setupForeignHubCore;
    SetupForeignSpokeCore public setupForeignSpokeCore;

    function test_LoadParamsFromEnv() public {
        string memory basePath = string.concat(vm.projectRoot(), "/script/deploy/");
        string memory hubFilename = _hubTestFilename();
        string memory spokeFilename = _spokeTestFilename();
        string memory hubCoreOutputJson = vm.readFile(string.concat(basePath, "outputs/hub-cores/", hubFilename));
        string memory spokeCoreOutputJson = vm.readFile(string.concat(basePath, "outputs/spoke-cores/", spokeFilename));

        vm.setEnv("TIMELOCK_CONTROLLER_INPUT_FILENAME", hubFilename);
        vm.setEnv("TIMELOCK_CONTROLLER_OUTPUT_FILENAME", hubFilename);
        deployTimelockController = new DeployTimelockController();
        deployTimelockController.loadParamsFromEnv();

        assertEq(
            deployTimelockController.outputPath(), string.concat(basePath, "outputs/timelock-controllers/", hubFilename)
        );
        address[] memory initialExecutors =
            vm.parseJsonAddressArray(deployTimelockController.inputJson(), ".initialExecutors");
        assertTrue(initialExecutors.length != 0);

        vm.setEnv("HUB_CORE_INPUT_FILENAME", hubFilename);
        vm.setEnv("HUB_CORE_OUTPUT_FILENAME", hubFilename);
        vm.setEnv("SKIP_AM_SETUP", "true");
        deployHubCore = new DeployHubCore();
        deployHubCore.loadParamsFromEnv();

        assertTrue(deployHubCore.skipAMSetup());
        assertEq(deployHubCore.outputPath(), string.concat(basePath, "outputs/hub-cores/", hubFilename));
        address hubSuperAdmin = vm.parseJsonAddress(deployHubCore.inputJson(), ".superAdminRoleGrant.account");
        assertTrue(hubSuperAdmin != address(0));

        // The hub strategy scripts read the factory from the hub core output file
        vm.setEnv("HUB_STRAT_INPUT_FILENAME", hubFilename);
        vm.setEnv("HUB_STRAT_OUTPUT_FILENAME", hubFilename);
        vm.setEnv("VIEW_MODE", "false");
        deployHubMachine = new DeployHubMachine();
        deployHubMachine.loadParamsFromEnv();

        assertFalse(deployHubMachine.viewMode());
        assertEq(deployHubMachine.coreFactory(), vm.parseJsonAddress(hubCoreOutputJson, ".HubCoreFactory"));
        assertEq(deployHubMachine.outputPath(), string.concat(basePath, "outputs/hub-machines/", hubFilename));
        address machineMechanic =
            vm.parseJsonAddress(deployHubMachine.inputJson(), ".makinaGovernableInitParams.initialMechanic");
        assertTrue(machineMechanic != address(0));

        deployMachineFromPreDeposit = new DeployHubMachineFromPreDeposit();
        deployMachineFromPreDeposit.loadParamsFromEnv();

        assertEq(deployMachineFromPreDeposit.coreFactory(), vm.parseJsonAddress(hubCoreOutputJson, ".HubCoreFactory"));
        assertEq(
            deployMachineFromPreDeposit.outputPath(),
            string.concat(basePath, "outputs/pre-deposit-migrations/", hubFilename)
        );
        machineMechanic =
            vm.parseJsonAddress(deployMachineFromPreDeposit.inputJson(), ".makinaGovernableInitParams.initialMechanic");
        assertTrue(machineMechanic != address(0));

        // In view mode, no output file is resolved
        vm.setEnv("VIEW_MODE", "true");
        deployPreDepositVault = new DeployPreDepositVault();
        deployPreDepositVault.loadParamsFromEnv();

        assertTrue(deployPreDepositVault.viewMode());
        assertEq(deployPreDepositVault.coreFactory(), vm.parseJsonAddress(hubCoreOutputJson, ".HubCoreFactory"));
        assertEq(deployPreDepositVault.outputPath(), "");
        address pdvRiskManager =
            vm.parseJsonAddress(deployPreDepositVault.inputJson(), ".preDepositVaultInitParams.initialRiskManager");
        assertTrue(pdvRiskManager != address(0));

        vm.setEnv("SPOKE_CORE_INPUT_FILENAME", spokeFilename);
        vm.setEnv("SPOKE_CORE_OUTPUT_FILENAME", spokeFilename);
        vm.setEnv("SKIP_AM_SETUP", "false");
        deploySpokeCore = new DeploySpokeCore();
        deploySpokeCore.loadParamsFromEnv();

        assertFalse(deploySpokeCore.skipAMSetup());
        assertEq(deploySpokeCore.outputPath(), string.concat(basePath, "outputs/spoke-cores/", spokeFilename));
        address spokeSuperAdmin = vm.parseJsonAddress(deploySpokeCore.inputJson(), ".superAdminRoleGrant.account");
        assertTrue(spokeSuperAdmin != address(0));

        // The spoke strategy script reads the factory from the spoke core output file
        vm.setEnv("SPOKE_STRAT_INPUT_FILENAME", spokeFilename);
        vm.setEnv("SPOKE_STRAT_OUTPUT_FILENAME", spokeFilename);
        vm.setEnv("VIEW_MODE", "false");
        deploySpokeCaliber = new DeploySpokeCaliber();
        deploySpokeCaliber.loadParamsFromEnv();

        assertFalse(deploySpokeCaliber.viewMode());
        assertEq(deploySpokeCaliber.coreFactory(), vm.parseJsonAddress(spokeCoreOutputJson, ".SpokeCoreFactory"));
        assertEq(deploySpokeCaliber.outputPath(), string.concat(basePath, "outputs/spoke-calibers/", spokeFilename));
        address caliberMechanic =
            vm.parseJsonAddress(deploySpokeCaliber.inputJson(), ".makinaGovernableInitParams.initialMechanic");
        assertTrue(caliberMechanic != address(0));

        // The foreign core scripts share the core env vars, and perform no AccessManager setup
        string memory foreignHubFilename = _foreignHubTestFilename();
        vm.setEnv("HUB_CORE_INPUT_FILENAME", foreignHubFilename);
        vm.setEnv("HUB_CORE_OUTPUT_FILENAME", foreignHubFilename);
        vm.setEnv("SKIP_AM_SETUP", "true");
        deployForeignHubCore = new DeployForeignHubCore();
        deployForeignHubCore.loadParamsFromEnv();

        assertFalse(deployForeignHubCore.skipAMSetup());
        assertEq(deployForeignHubCore.outputPath(), string.concat(basePath, "outputs/hub-cores/", foreignHubFilename));
        assertEq(
            vm.parseJsonAddress(deployForeignHubCore.inputJson(), ".mainCoreRegistry"),
            vm.parseJsonAddress(spokeCoreOutputJson, ".SpokeCoreRegistry")
        );
        assertTrue(vm.parseJsonAddress(deployForeignHubCore.inputJson(), ".creForwarder") != address(0));

        vm.setEnv("VIEW_MODE", "true");
        setupForeignHubCore = new SetupForeignHubCore();
        setupForeignHubCore.loadParamsFromEnv();

        assertTrue(setupForeignHubCore.viewMode());
        assertEq(setupForeignHubCore.inputJson(), deployForeignHubCore.inputJson());
        assertTrue(vm.parseJsonAddress(setupForeignHubCore.outputJson(), ".HubCoreRegistry") != address(0));

        string memory foreignSpokeFilename = _foreignSpokeTestFilename();
        vm.setEnv("SPOKE_CORE_INPUT_FILENAME", foreignSpokeFilename);
        vm.setEnv("SPOKE_CORE_OUTPUT_FILENAME", foreignSpokeFilename);
        deployForeignSpokeCore = new DeployForeignSpokeCore();
        deployForeignSpokeCore.loadParamsFromEnv();

        assertFalse(deployForeignSpokeCore.skipAMSetup());
        assertEq(
            deployForeignSpokeCore.outputPath(), string.concat(basePath, "outputs/spoke-cores/", foreignSpokeFilename)
        );
        assertEq(
            vm.parseJsonAddress(deployForeignSpokeCore.inputJson(), ".mainCoreRegistry"),
            vm.parseJsonAddress(hubCoreOutputJson, ".HubCoreRegistry")
        );
        assertEq(vm.parseJsonUint(deployForeignSpokeCore.inputJson(), ".hubChainId"), BASE_CHAIN_ID);

        vm.setEnv("VIEW_MODE", "false");
        setupForeignSpokeCore = new SetupForeignSpokeCore();
        setupForeignSpokeCore.loadParamsFromEnv();

        assertFalse(setupForeignSpokeCore.viewMode());
        assertEq(setupForeignSpokeCore.inputJson(), deployForeignSpokeCore.inputJson());
        assertTrue(vm.parseJsonAddress(setupForeignSpokeCore.outputJson(), ".SpokeCoreRegistry") != address(0));
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

        // Check that the deployment matches the committed record
        string memory outputJson = _record("hub-cores", _hubTestFilename());
        assertEq(vm.parseJsonAddress(outputJson, ".AccessManager"), address(hubCoreDeployment.accessManager));
        assertEq(vm.parseJsonAddress(outputJson, ".HubCoreFactory"), address(hubCoreDeployment.hubCoreFactory));
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

        // Check that the AM setup was skipped: the super admin was not granted the ADMIN_ROLE
        address superAdmin = vm.parseJsonAddress(deployHubCore.inputJson(), ".superAdminRoleGrant.account");
        (bool isMember,) =
            hubCoreDeployment.accessManager.hasRole(hubCoreDeployment.accessManager.ADMIN_ROLE(), superAdmin);
        assertFalse(isMember);

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

        // Check that the deployment matches the committed record
        assertEq(vm.parseJsonAddress(_record("hub-machines", _hubTestFilename()), ".machine"), address(machine));
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

        // PreDeposit Vault deployment
        deployPreDepositVault = new DeployPreDepositVault();
        deployPreDepositVault.setParams(address(hubCoreDeployment.hubCoreFactory), _hubTestFilename(), "");
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

        // Check that the deployment matches the committed record
        assertEq(
            vm.parseJsonAddress(_record("pre-deposit-vaults", _hubTestFilename()), ".preDepositVault"),
            address(preDepositVault)
        );
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

        // Check that the deployment matches the committed record
        assertEq(
            vm.parseJsonAddress(_record("pre-deposit-migrations", _hubTestFilename()), ".machine"), address(machine)
        );
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

        // Check that the deployment matches the committed record
        string memory outputJson = _record("spoke-cores", _spokeTestFilename());
        assertEq(vm.parseJsonAddress(outputJson, ".AccessManager"), address(spokeCoreDeployment.accessManager));
        assertEq(vm.parseJsonAddress(outputJson, ".SpokeCoreFactory"), address(spokeCoreDeployment.spokeCoreFactory));
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

        // Check that the deployment matches the committed record
        assertEq(
            vm.parseJsonAddress(_record("spoke-calibers", _spokeTestFilename()), ".caliber"), address(spokeCaliber)
        );
    }

    function testScript_DeployForeignHubCore() public {
        vm.createSelectFork({urlOrAlias: getChain(BASE_CHAIN_ID).chainAlias});

        // Main instance: Base hosts a spoke core of the Ethereum hub. Its deployer keeps ADMIN_ROLE on the shared
        // AccessManager, so that the foreign setup can be broadcast below.
        deploySpokeCore = new DeploySpokeCore();
        deploySpokeCore.setFilenames(_spokeTestFilename(), "");
        deploySpokeCore.setSkipAMSetup(true);
        deploySpokeCore.run();

        (SpokeCore memory mainCore,) = deploySpokeCore.deployment();

        // Foreign instance: Base is also the hub of its own instance
        deployForeignHubCore = new DeployForeignHubCore();
        deployForeignHubCore.setFilenames(_foreignHubTestFilename(), "");
        deployForeignHubCore.run();

        (HubCore memory core, UpgradeableBeacon[] memory bridgeAdapterBeacons) = deployForeignHubCore.deployment();

        // Setup, broadcast from the deployer holding ADMIN_ROLE
        setupForeignHubCore = new SetupForeignHubCore();
        setupForeignHubCore.setFilenames(_foreignHubTestFilename(), _foreignHubTestFilename());
        setupForeignHubCore.run();

        // Check that the chain-scoped components are shared
        assertEq(address(core.accessManager), address(mainCore.accessManager));
        assertEq(address(core.oracleRegistry), address(mainCore.oracleRegistry));
        assertEq(address(core.tokenRegistry), address(mainCore.tokenRegistry));
        assertEq(
            ICaliber(core.caliberBeacon.implementation()).weirollVm(),
            ICaliber(mainCore.caliberBeacon.implementation()).weirollVm()
        );

        // Check that the instance-scoped components are new, owned by the shared AccessManager
        assertNotEq(address(core.hubCoreRegistry), address(mainCore.spokeCoreRegistry));
        assertNotEq(address(core.hubCoreFactory), address(mainCore.spokeCoreFactory));
        assertNotEq(address(core.swapModule), address(mainCore.swapModule));
        assertNotEq(address(core.caliberBeacon), address(mainCore.caliberBeacon));
        assertEq(Ownable(getProxyAdmin(address(core.hubCoreRegistry))).owner(), address(core.accessManager));
        assertEq(Ownable(getProxyAdmin(address(core.hubCoreFactory))).owner(), address(core.accessManager));
        assertEq(Ownable(getProxyAdmin(address(core.swapModule))).owner(), address(core.accessManager));
        assertEq(core.caliberBeacon.owner(), address(core.accessManager));
        assertEq(core.machineBeacon.owner(), address(core.accessManager));
        assertEq(core.preDepositVaultBeacon.owner(), address(core.accessManager));

        // Check that the instance-scoped implementations are bound to the new registry
        address registry = address(core.hubCoreRegistry);
        assertEq(IMakinaContext(address(core.hubCoreFactory)).registry(), registry);
        assertEq(IMakinaContext(address(core.swapModule)).registry(), registry);
        _assertBoundTo(core.caliberBeacon, registry);
        _assertBoundTo(core.machineBeacon, registry);
        _assertBoundTo(core.preDepositVaultBeacon, registry);

        // Check that HubCoreRegistry is correctly set up
        assertEq(IAccessManaged(registry).authority(), address(core.accessManager));
        assertEq(core.hubCoreRegistry.oracleRegistry(), address(core.oracleRegistry));
        assertEq(core.hubCoreRegistry.tokenRegistry(), address(core.tokenRegistry));
        assertEq(core.hubCoreRegistry.coreFactory(), address(core.hubCoreFactory));
        assertEq(core.hubCoreRegistry.swapModule(), address(core.swapModule));
        assertEq(core.hubCoreRegistry.caliberBeacon(), address(core.caliberBeacon));
        assertEq(core.hubCoreRegistry.machineBeacon(), address(core.machineBeacon));
        assertEq(core.hubCoreRegistry.preDepositVaultBeacon(), address(core.preDepositVaultBeacon));
        _assertForeignBridgesSetup(
            deployForeignHubCore.inputJson(), core.hubCoreRegistry, mainCore.spokeCoreRegistry, bridgeAdapterBeacons
        );
        _assertSwapModuleSetup(deployForeignHubCore.inputJson(), core.swapModule);

        // Check that the AccessManager function roles are set up
        _assertForeignCoreAMFunctionRoles(core.accessManager, registry, address(core.hubCoreFactory), core.swapModule);
        _assertBeaconAMFunctionRole(core.accessManager, core.caliberBeacon);
        _assertBeaconAMFunctionRole(core.accessManager, core.machineBeacon);
        _assertBeaconAMFunctionRole(core.accessManager, core.preDepositVaultBeacon);
        assertEq(
            core.accessManager
                .getTargetFunctionRole(address(core.hubCoreFactory), IHubCoreFactory.createMachine.selector),
            Roles.STRATEGY_DEPLOYMENT_ROLE
        );
        assertEq(setupForeignHubCore.callsLength(), 19);

        // Check that the deployment matches the committed record
        string memory outputJson = _record("hub-cores", _foreignHubTestFilename());
        assertEq(vm.parseJsonAddress(outputJson, ".HubCoreRegistry"), registry);
        assertEq(vm.parseJsonAddress(outputJson, ".HubCoreFactory"), address(core.hubCoreFactory));
    }

    function testScript_DeployForeignSpokeCore() public {
        vm.createSelectFork({urlOrAlias: getChain(ETHEREUM_CHAIN_ID).chainAlias});

        // Main instance: Ethereum is the hub. Its deployer keeps ADMIN_ROLE on the shared AccessManager.
        deployHubCore = new DeployHubCore();
        deployHubCore.setFilenames(_hubTestFilename(), "");
        deployHubCore.setSkipAMSetup(true);
        deployHubCore.run();

        (HubCore memory mainCore,) = deployHubCore.deployment();

        // Foreign instance: Ethereum is also a spoke of the Base hub
        deployForeignSpokeCore = new DeployForeignSpokeCore();
        deployForeignSpokeCore.setFilenames(_foreignSpokeTestFilename(), "");
        deployForeignSpokeCore.run();

        (SpokeCore memory core, UpgradeableBeacon[] memory bridgeAdapterBeacons) = deployForeignSpokeCore.deployment();

        // Setup, broadcast from the deployer holding ADMIN_ROLE
        setupForeignSpokeCore = new SetupForeignSpokeCore();
        setupForeignSpokeCore.setFilenames(_foreignSpokeTestFilename(), _foreignSpokeTestFilename());
        setupForeignSpokeCore.run();

        // Check that the chain-scoped components are shared
        assertEq(address(core.accessManager), address(mainCore.accessManager));
        assertEq(address(core.oracleRegistry), address(mainCore.oracleRegistry));
        assertEq(address(core.tokenRegistry), address(mainCore.tokenRegistry));
        assertEq(
            ICaliber(core.caliberBeacon.implementation()).weirollVm(),
            ICaliber(mainCore.caliberBeacon.implementation()).weirollVm()
        );

        // Check that the instance-scoped components are new, owned by the shared AccessManager
        assertNotEq(address(core.spokeCoreRegistry), address(mainCore.hubCoreRegistry));
        assertNotEq(address(core.spokeCoreFactory), address(mainCore.hubCoreFactory));
        assertNotEq(address(core.swapModule), address(mainCore.swapModule));
        assertNotEq(address(core.caliberBeacon), address(mainCore.caliberBeacon));
        assertEq(Ownable(getProxyAdmin(address(core.spokeCoreRegistry))).owner(), address(core.accessManager));
        assertEq(Ownable(getProxyAdmin(address(core.spokeCoreFactory))).owner(), address(core.accessManager));
        assertEq(Ownable(getProxyAdmin(address(core.swapModule))).owner(), address(core.accessManager));
        assertEq(core.caliberBeacon.owner(), address(core.accessManager));
        assertEq(core.caliberMailboxBeacon.owner(), address(core.accessManager));

        // Check that the instance-scoped implementations are bound to the new registry, and the mailbox to the hub
        address registry = address(core.spokeCoreRegistry);
        assertEq(IMakinaContext(address(core.spokeCoreFactory)).registry(), registry);
        assertEq(IMakinaContext(address(core.swapModule)).registry(), registry);
        _assertBoundTo(core.caliberBeacon, registry);
        _assertBoundTo(core.caliberMailboxBeacon, registry);
        assertEq(ICaliberMailbox(core.caliberMailboxBeacon.implementation()).hubChainId(), BASE_CHAIN_ID);

        // Check that SpokeCoreRegistry is correctly set up
        assertEq(IAccessManaged(registry).authority(), address(core.accessManager));
        assertEq(core.spokeCoreRegistry.oracleRegistry(), address(core.oracleRegistry));
        assertEq(core.spokeCoreRegistry.tokenRegistry(), address(core.tokenRegistry));
        assertEq(core.spokeCoreRegistry.coreFactory(), address(core.spokeCoreFactory));
        assertEq(core.spokeCoreRegistry.swapModule(), address(core.swapModule));
        assertEq(core.spokeCoreRegistry.caliberBeacon(), address(core.caliberBeacon));
        assertEq(core.spokeCoreRegistry.caliberMailboxBeacon(), address(core.caliberMailboxBeacon));
        _assertForeignBridgesSetup(
            deployForeignSpokeCore.inputJson(), core.spokeCoreRegistry, mainCore.hubCoreRegistry, bridgeAdapterBeacons
        );
        _assertSwapModuleSetup(deployForeignSpokeCore.inputJson(), core.swapModule);

        // Check that the AccessManager function roles are set up
        _assertForeignCoreAMFunctionRoles(core.accessManager, registry, address(core.spokeCoreFactory), core.swapModule);
        _assertBeaconAMFunctionRole(core.accessManager, core.caliberBeacon);
        _assertBeaconAMFunctionRole(core.accessManager, core.caliberMailboxBeacon);
        assertEq(
            core.accessManager
                .getTargetFunctionRole(address(core.spokeCoreFactory), ISpokeCoreFactory.createCaliber.selector),
            Roles.STRATEGY_DEPLOYMENT_ROLE
        );
        assertEq(setupForeignSpokeCore.callsLength(), 17);

        // Check that the deployment matches the committed record
        string memory outputJson = _record("spoke-cores", _foreignSpokeTestFilename());
        assertEq(vm.parseJsonAddress(outputJson, ".SpokeCoreRegistry"), registry);
        assertEq(vm.parseJsonAddress(outputJson, ".SpokeCoreFactory"), address(core.spokeCoreFactory));
    }

    function testScript_SetupForeignHubCore_ViewMode() public {
        vm.createSelectFork({urlOrAlias: getChain(BASE_CHAIN_ID).chainAlias});

        deploySpokeCore = new DeploySpokeCore();
        deploySpokeCore.setFilenames(_spokeTestFilename(), "");
        deploySpokeCore.setSkipAMSetup(true);
        deploySpokeCore.run();

        deployForeignHubCore = new DeployForeignHubCore();
        deployForeignHubCore.setFilenames(_foreignHubTestFilename(), "");
        deployForeignHubCore.run();

        (HubCore memory core,) = deployForeignHubCore.deployment();

        // View mode: the calls are built and logged, nothing is sent
        setupForeignHubCore = new SetupForeignHubCore();
        setupForeignHubCore.setFilenames(_foreignHubTestFilename(), _foreignHubTestFilename());
        setupForeignHubCore.setViewMode(true);

        vm.expectCall(address(core.hubCoreRegistry), abi.encodeWithSelector(ICoreRegistry.setCoreFactory.selector), 0);
        vm.expectCall(
            address(core.accessManager), abi.encodeWithSelector(IAccessManager.setTargetFunctionRole.selector), 0
        );
        setupForeignHubCore.run();

        assertEq(setupForeignHubCore.callsLength(), 19);
        assertEq(core.hubCoreRegistry.coreFactory(), address(0));
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

        // Check that the deployment matches the committed record
        assertEq(
            vm.parseJsonAddress(_record("timelock-controllers", _hubTestFilename()), ".timelockController"),
            address(timelockController)
        );
    }

    function test_SetupAccessManagerRoles_KeepsAdminRoleWhenDeployerIsSuperAdmin() public {
        address admin = address(this);
        // The `deployHubCore` script instance shadows `Base.deployHubCore`, hence the explicit base call
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

        AMRoleGrant memory superAdminRoleGrant =
            AMRoleGrant({roleId: 0, account: makeAddr("MakinaDAO"), executionDelay: 0});
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

    function _spokeTestFilename() internal returns (string memory) {
        return string.concat(getChain(BASE_CHAIN_ID).name, "-Test.json");
    }

    /// @dev Hub core of the Base hub instance, on Base.
    function _foreignHubTestFilename() internal returns (string memory) {
        return string.concat("BaseHub-", getChain(BASE_CHAIN_ID).name, "-Test.json");
    }

    /// @dev Spoke core of the Base hub instance, on Ethereum.
    function _foreignSpokeTestFilename() internal returns (string memory) {
        return string.concat("BaseHub-", getChain(ETHEREUM_CHAIN_ID).name, "-Test.json");
    }

    function _assertAccessManagerOwnsItsProxyAdmin(AccessManagerUpgradeable accessManager) internal view {
        assertEq(Ownable(getProxyAdmin(address(accessManager))).owner(), address(accessManager));
    }

    function _assertBoundTo(UpgradeableBeacon beacon, address registry) internal view {
        assertEq(IMakinaContext(beacon.implementation()).registry(), registry);
    }

    /// @dev The foreign registry holds the new adapter beacons and the main registry's bridge configs.
    function _assertForeignBridgesSetup(
        string memory inputJson,
        ICoreRegistry registry,
        ICoreRegistry mainRegistry,
        UpgradeableBeacon[] memory bridgeAdapterBeacons
    ) internal view {
        BridgeData[] memory _bridgesData = parseBridgesData(inputJson, ".bridgesTargets");
        assertEq(bridgeAdapterBeacons.length, _bridgesData.length);
        for (uint256 i; i < _bridgesData.length; ++i) {
            uint16 bridgeId = _bridgesData[i].bridgeId;
            assertEq(registry.bridgeAdapterBeacon(bridgeId), address(bridgeAdapterBeacons[i]));
            assertEq(registry.bridgeConfig(bridgeId), mainRegistry.bridgeConfig(bridgeId));
            _assertBoundTo(bridgeAdapterBeacons[i], address(registry));
            IBridgeAdapter implementation = IBridgeAdapter(bridgeAdapterBeacons[i].implementation());
            assertEq(implementation.approvalTarget(), _bridgesData[i].approvalTarget);
            assertEq(implementation.executionTarget(), _bridgesData[i].executionTarget);
            assertEq(implementation.receiveSource(), _bridgesData[i].receiveSource);
            _assertBeaconAMFunctionRole(
                AccessManagerUpgradeable(IAccessManaged(address(registry)).authority()), bridgeAdapterBeacons[i]
            );
        }
    }

    function _assertSwapModuleSetup(string memory inputJson, ISwapModule swapModule) internal view {
        SwapperData[] memory _swappersData = parseSwappersData(inputJson, ".swappersTargets");
        for (uint256 i; i < _swappersData.length; ++i) {
            (address approvalTarget, address executionTarget) = swapModule.getSwapperTargets(_swappersData[i].swapperId);
            assertEq(approvalTarget, _swappersData[i].approvalTarget);
            assertEq(executionTarget, _swappersData[i].executionTarget);
        }
    }

    /// @dev Function roles shared by the hub and spoke foreign cores, plus the factory's ADMIN_ROLE grant.
    function _assertForeignCoreAMFunctionRoles(
        AccessManagerUpgradeable accessManager,
        address registry,
        address factory,
        ISwapModule swapModule
    ) internal view {
        assertEq(
            accessManager.getTargetFunctionRole(getProxyAdmin(registry), ProxyAdmin.upgradeAndCall.selector),
            Roles.INFRA_UPGRADE_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(getProxyAdmin(factory), ProxyAdmin.upgradeAndCall.selector),
            Roles.INFRA_UPGRADE_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(getProxyAdmin(address(swapModule)), ProxyAdmin.upgradeAndCall.selector),
            Roles.INFRA_UPGRADE_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(registry, ICoreRegistry.setCoreFactory.selector),
            Roles.INFRA_UPGRADE_ROLE
        );
        assertEq(
            accessManager.getTargetFunctionRole(address(swapModule), ISwapModule.setSwapperTargets.selector),
            Roles.INFRA_CONFIG_ROLE
        );
        (bool isMember,) = accessManager.hasRole(accessManager.ADMIN_ROLE(), factory);
        assertTrue(isMember);
    }

    function _assertBeaconAMFunctionRole(AccessManagerUpgradeable accessManager, UpgradeableBeacon beacon)
        internal
        view
    {
        assertEq(
            accessManager.getTargetFunctionRole(address(beacon), UpgradeableBeacon.upgradeTo.selector),
            Roles.INFRA_UPGRADE_ROLE
        );
    }

    /// @dev A committed test record under `outputs/`. Test deployments are deterministic, so they match the records
    ///      without rewriting them. A failing comparison means the record must be regenerated, by running the
    ///      script with that output filename.
    function _record(string memory dir, string memory filename) internal view returns (string memory) {
        return vm.readFile(string.concat(vm.projectRoot(), "/script/deploy/outputs/", dir, "/", filename));
    }
}
