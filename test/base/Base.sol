// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {AcrossV3BridgeAdapter} from "../../src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {AcrossV3BridgeConfig} from "../../src/bridge/configs/AcrossV3BridgeConfig.sol";
import {ChainsInfo} from "../utils/ChainsInfo.sol";
import {Caliber} from "../../src/caliber/Caliber.sol";
import {SpokeCoreFactory} from "../../src/factories/SpokeCoreFactory.sol";
import {CaliberMailbox} from "../../src/caliber/CaliberMailbox.sol";
import {ChainRegistry} from "../../src/registries/ChainRegistry.sol";
import {HubCoreRegistry} from "../../src/registries/HubCoreRegistry.sol";
import {IAcrossV3BridgeConfig} from "../../src/interfaces/IAcrossV3BridgeConfig.sol";
import {IBridgeController} from "../../src/interfaces/IBridgeController.sol";
import {ICaliber} from "../../src/interfaces/ICaliber.sol";
import {ICaliberMailbox} from "../../src/interfaces/ICaliberMailbox.sol";
import {IChainRegistry} from "../../src/interfaces/IChainRegistry.sol";
import {ICoreRegistry} from "../../src/interfaces/ICoreRegistry.sol";
import {IHubCoreFactory} from "../../src/interfaces/IHubCoreFactory.sol";
import {IHubCoreRegistry} from "../../src/interfaces/IHubCoreRegistry.sol";
import {ILayerZeroV2BridgeConfig} from "../../src/interfaces/ILayerZeroV2BridgeConfig.sol";
import {IOracleRegistry} from "../../src/interfaces/IOracleRegistry.sol";
import {IRCodeReader} from "../utils/IRCodeReader.sol";
import {ISpokeCoreFactory} from "../../src/interfaces/ISpokeCoreFactory.sol";
import {ISpokeCoreRegistry} from "../../src/interfaces/ISpokeCoreRegistry.sol";
import {ISwapModule} from "../../src/interfaces/ISwapModule.sol";
import {ITokenRegistry} from "../../src/interfaces/ITokenRegistry.sol";
import {IntegrationIds} from "../utils/IntegrationIds.sol";
import {IMachine} from "../../src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "../../src/interfaces/IMakinaGovernable.sol";
import {LayerZeroV2BridgeAdapter} from "../../src/bridge/adapters/LayerZeroV2BridgeAdapter.sol";
import {LayerZeroV2BridgeConfig} from "../../src/bridge/configs/LayerZeroV2BridgeConfig.sol";
import {Machine} from "../../src/machine/Machine.sol";
import {HubCoreFactory} from "../../src/factories/HubCoreFactory.sol";
import {OracleRegistry} from "../../src/registries/OracleRegistry.sol";
import {PreDepositVault} from "../../src/pre-deposit/PreDepositVault.sol";
import {Roles} from "../utils/Roles.sol";
import {SaltDomains} from "../utils/SaltDomains.sol";
import {SpokeCoreRegistry} from "../../src/registries/SpokeCoreRegistry.sol";
import {SwapModule} from "../../src/swap/SwapModule.sol";
import {TokenRegistry} from "../../src/registries/TokenRegistry.sol";

abstract contract Base is IRCodeReader, SaltDomains, IntegrationIds {
    struct HubCore {
        AccessManagerUpgradeable accessManager;
        OracleRegistry oracleRegistry;
        SwapModule swapModule;
        TokenRegistry tokenRegistry;
        ChainRegistry chainRegistry;
        HubCoreRegistry hubCoreRegistry;
        HubCoreFactory hubCoreFactory;
        UpgradeableBeacon caliberBeacon;
        UpgradeableBeacon machineBeacon;
        UpgradeableBeacon preDepositVaultBeacon;
    }

    struct SpokeCore {
        AccessManagerUpgradeable accessManager;
        OracleRegistry oracleRegistry;
        SwapModule swapModule;
        TokenRegistry tokenRegistry;
        SpokeCoreRegistry spokeCoreRegistry;
        SpokeCoreFactory spokeCoreFactory;
        UpgradeableBeacon caliberBeacon;
        UpgradeableBeacon caliberMailboxBeacon;
    }

    struct PriceFeedRoute {
        address feed1;
        address feed2;
        uint256 stalenessThreshold1;
        uint256 stalenessThreshold2;
        address token;
    }

    struct TokenToRegister {
        uint256 foreignEvmChainId;
        address foreignToken;
        address localToken;
    }

    struct SwapperData {
        address approvalTarget;
        address executionTarget;
        uint16 swapperId;
    }

    struct BridgeData {
        address approvalTarget;
        uint16 bridgeId;
        address executionTarget;
        address receiveSource;
    }

    ///
    /// CORE DEPLOYMENTS
    ///

    function deployHubCore(address initialAMAdmin, address upgradeAdmin, address wormhole)
        internal
        returns (HubCore memory deployment)
    {
        // Access Manager
        deployment.accessManager = _deployAccessManager(initialAMAdmin, upgradeAdmin);

        // Oracle Registry
        deployment.oracleRegistry = _deployOracleRegistry(upgradeAdmin, address(deployment.accessManager));

        // Token Registry
        deployment.tokenRegistry = _deployTokenRegistry(upgradeAdmin, address(deployment.accessManager));

        // Chain Registry
        deployment.chainRegistry = _deployChainRegistry(upgradeAdmin, address(deployment.accessManager));

        // Hub Core Registry
        deployment.hubCoreRegistry = _deployHubCoreRegistry(
            upgradeAdmin,
            address(deployment.oracleRegistry),
            address(deployment.tokenRegistry),
            address(deployment.chainRegistry),
            address(deployment.accessManager)
        );

        // Hub Core Factory
        deployment.hubCoreFactory =
            _deployHubCoreFactory(upgradeAdmin, address(deployment.hubCoreRegistry), address(deployment.accessManager));

        // Swap Module
        deployment.swapModule =
            _deploySwapModule(upgradeAdmin, address(deployment.hubCoreRegistry), address(deployment.accessManager));

        // Weiroll VM
        address weirollVM = _deployWeirollVM();

        // Caliber Beacon
        deployment.caliberBeacon = _deployCaliberBeacon(upgradeAdmin, address(deployment.hubCoreRegistry), weirollVM);

        // Machine Beacon
        deployment.machineBeacon = _deployMachineBeacon(upgradeAdmin, address(deployment.hubCoreRegistry), wormhole);

        // PreDeposit Vault Beacon
        deployment.preDepositVaultBeacon =
            _deployPreDepositVaultBeacon(upgradeAdmin, address(deployment.hubCoreRegistry));
    }

    function deploySpokeCore(address initialAMAdmin, address upgradeAdmin, uint256 hubChainId)
        internal
        returns (SpokeCore memory deployment)
    {
        // Access Manager
        deployment.accessManager = _deployAccessManager(initialAMAdmin, upgradeAdmin);

        // Oracle Registry
        deployment.oracleRegistry = _deployOracleRegistry(upgradeAdmin, address(deployment.accessManager));

        // Token Registry
        deployment.tokenRegistry = _deployTokenRegistry(upgradeAdmin, address(deployment.accessManager));

        // Spoke Core Registry
        deployment.spokeCoreRegistry = _deploySpokeCoreRegistry(
            upgradeAdmin,
            address(deployment.oracleRegistry),
            address(deployment.tokenRegistry),
            address(deployment.accessManager)
        );

        // Spoke Core Factory
        deployment.spokeCoreFactory = _deploySpokeCoreFactory(
            upgradeAdmin, address(deployment.spokeCoreRegistry), address(deployment.accessManager)
        );

        // Swap Module
        deployment.swapModule =
            _deploySwapModule(upgradeAdmin, address(deployment.spokeCoreRegistry), address(deployment.accessManager));

        // Weiroll VM
        address weirollVM = _deployWeirollVM();

        // Caliber Beacon
        deployment.caliberBeacon = _deployCaliberBeacon(upgradeAdmin, address(deployment.spokeCoreRegistry), weirollVM);

        // Caliber Mailbox Beacon
        deployment.caliberMailboxBeacon =
            _deployCaliberMailboxBeacon(upgradeAdmin, address(deployment.spokeCoreRegistry), hubChainId);
    }

    ///
    /// REGISTRIES SETUP
    ///

    function setupHubCoreRegistry(HubCore memory deployment) public {
        deployment.hubCoreRegistry.setOracleRegistry(address(deployment.oracleRegistry));
        deployment.hubCoreRegistry.setSwapModule(address(deployment.swapModule));
        deployment.hubCoreRegistry.setTokenRegistry(address(deployment.tokenRegistry));
        deployment.hubCoreRegistry.setChainRegistry(address(deployment.chainRegistry));
        deployment.hubCoreRegistry.setCoreFactory(address(deployment.hubCoreFactory));
        deployment.hubCoreRegistry.setCaliberBeacon(address(deployment.caliberBeacon));
        deployment.hubCoreRegistry.setMachineBeacon(address(deployment.machineBeacon));
        deployment.hubCoreRegistry.setPreDepositVaultBeacon(address(deployment.preDepositVaultBeacon));
    }

    function setupSpokeCoreRegistry(SpokeCore memory deployment) public {
        deployment.spokeCoreRegistry.setOracleRegistry(address(deployment.oracleRegistry));
        deployment.spokeCoreRegistry.setSwapModule(address(deployment.swapModule));
        deployment.spokeCoreRegistry.setTokenRegistry(address(deployment.tokenRegistry));
        deployment.spokeCoreRegistry.setCoreFactory(address(deployment.spokeCoreFactory));
        deployment.spokeCoreRegistry.setCaliberBeacon(address(deployment.caliberBeacon));
        deployment.spokeCoreRegistry.setCaliberMailboxBeacon(address(deployment.caliberMailboxBeacon));
    }

    function setupOracleRegistry(OracleRegistry oracleRegistry, PriceFeedRoute[] memory priceFeedRoutes) public {
        for (uint256 i; i < priceFeedRoutes.length; i++) {
            oracleRegistry.setFeedRoute(
                priceFeedRoutes[i].token,
                priceFeedRoutes[i].feed1,
                priceFeedRoutes[i].stalenessThreshold1,
                priceFeedRoutes[i].feed2,
                priceFeedRoutes[i].stalenessThreshold2
            );
        }
    }

    function setupChainRegistry(ChainRegistry chainRegistry, uint256[] memory evmChainIds) public {
        for (uint256 i; i < evmChainIds.length; i++) {
            uint256 evmChainId = evmChainIds[i];
            chainRegistry.setChainIds(evmChainId, ChainsInfo.getChainInfo(evmChainId).wormholeChainId);
        }
    }

    function setupTokenRegistry(TokenRegistry tokenRegistry, TokenToRegister[] memory tokensToRegister) public {
        for (uint256 i; i < tokensToRegister.length; i++) {
            tokenRegistry.setToken(
                tokensToRegister[i].localToken, tokensToRegister[i].foreignEvmChainId, tokensToRegister[i].foreignToken
            );
        }
    }

    ///
    /// SWAPMODULE SETUP
    ///

    function setupSwapModule(SwapModule swapModule, SwapperData[] memory swappersData) public {
        for (uint256 i; i < swappersData.length; i++) {
            swapModule.setSwapperTargets(
                swappersData[i].swapperId, swappersData[i].approvalTarget, swappersData[i].executionTarget
            );
        }
    }

    ///
    /// BRIDGE ADAPTER BEACONS DEPLOYMENTS & SETUP
    ///

    function deployAndSetupBridges(
        address proxyOwner,
        ICoreRegistry coreRegistry,
        AccessManagerUpgradeable accessManager,
        BridgeData[] memory bridgesData
    )
        public
        returns (UpgradeableBeacon[] memory bridgeAdapterBeacons, TransparentUpgradeableProxy[] memory bridgeConfigs)
    {
        bridgeConfigs = new TransparentUpgradeableProxy[](bridgesData.length);
        bridgeAdapterBeacons = new UpgradeableBeacon[](bridgesData.length);
        for (uint256 i; i < bridgesData.length; i++) {
            uint16 bridgeId = bridgesData[i].bridgeId;
            TransparentUpgradeableProxy bc;
            UpgradeableBeacon baBeacon;
            if (bridgeId == ACROSS_V3_BRIDGE_ID) {
                baBeacon = _deployAcrossV3BridgeAdapterBeacon(
                    proxyOwner, address(coreRegistry), bridgesData[i].executionTarget
                );
                bc = TransparentUpgradeableProxy(
                    payable(address(_deployAcrossV3BridgeConfig(proxyOwner, address(accessManager))))
                );
                _setupAcrossV3BridgeConfigAMFunctionRoles(address(accessManager), address(bc));
            } else if (bridgeId == LAYER_ZERO_V2_BRIDGE_ID) {
                baBeacon = _deployLayerZeroV2BridgeAdapterBeacon(
                    proxyOwner, address(coreRegistry), bridgesData[i].receiveSource
                );
                bc = TransparentUpgradeableProxy(
                    payable(address(_deployLayerZeroV2BridgeConfig(proxyOwner, address(accessManager))))
                );
                _setupLayerZeroV2BridgeConfigAMFunctionRoles(address(accessManager), address(bc));
            } else {
                revert("Bridge not supported");
            }
            bridgeAdapterBeacons[i] = baBeacon;
            bridgeConfigs[i] = bc;
            coreRegistry.setBridgeAdapterBeacon(bridgeId, address(baBeacon));
            coreRegistry.setBridgeConfig(bridgeId, address(bc));
        }
    }

    ///
    /// ACCESS MANAGER SETUP
    ///

    function setupAccessManagerRoles(
        AccessManagerUpgradeable accessManager,
        address superAdmin,
        address infraSetupAdmin,
        address stratDeployAdmin,
        address stratCompSetupAdmin,
        address stratMgmtSetupAdmin,
        address deployer
    ) public {
        // Grant roles to the relevant accounts
        accessManager.grantRole(accessManager.ADMIN_ROLE(), superAdmin, 0);
        accessManager.grantRole(Roles.INFRA_SETUP_ROLE, infraSetupAdmin, 0);
        accessManager.grantRole(Roles.STRATEGY_DEPLOYMENT_ROLE, stratDeployAdmin, 0);
        accessManager.grantRole(Roles.STRATEGY_COMPONENTS_SETUP_ROLE, stratCompSetupAdmin, 0);
        accessManager.grantRole(Roles.STRATEGY_MANAGEMENT_SETUP_ROLE, stratMgmtSetupAdmin, 0);

        // Revoke roles from the deployer
        accessManager.revokeRole(accessManager.ADMIN_ROLE(), address(deployer));
    }

    function setupHubCoreAMFunctionRoles(HubCore memory deployment) public {
        // HubCoreRegistry
        bytes4[] memory hubCoreRegistrySelectors = new bytes4[](11);
        hubCoreRegistrySelectors[0] = ICoreRegistry.setCoreFactory.selector;
        hubCoreRegistrySelectors[1] = ICoreRegistry.setOracleRegistry.selector;
        hubCoreRegistrySelectors[2] = ICoreRegistry.setTokenRegistry.selector;
        hubCoreRegistrySelectors[3] = ICoreRegistry.setSwapModule.selector;
        hubCoreRegistrySelectors[4] = ICoreRegistry.setFlashLoanModule.selector;
        hubCoreRegistrySelectors[5] = ICoreRegistry.setCaliberBeacon.selector;
        hubCoreRegistrySelectors[6] = ICoreRegistry.setBridgeAdapterBeacon.selector;
        hubCoreRegistrySelectors[7] = ICoreRegistry.setBridgeConfig.selector;
        hubCoreRegistrySelectors[8] = IHubCoreRegistry.setChainRegistry.selector;
        hubCoreRegistrySelectors[9] = IHubCoreRegistry.setMachineBeacon.selector;
        hubCoreRegistrySelectors[10] = IHubCoreRegistry.setPreDepositVaultBeacon.selector;
        deployment.accessManager.setTargetFunctionRole(
            address(deployment.hubCoreRegistry), hubCoreRegistrySelectors, Roles.INFRA_SETUP_ROLE
        );

        // ChainRegistry
        _setupChainRegistryAMFunctionRoles(deployment.accessManager, address(deployment.chainRegistry));

        // OracleRegistry
        _setupOracleRegistryAMFunctionRoles(deployment.accessManager, address(deployment.oracleRegistry));

        // TokenRegistry
        _setupTokenRegistryAMFunctionRoles(deployment.accessManager, address(deployment.tokenRegistry));

        // HubCoreFactory
        bytes4[] memory hubCoreFactorySelectors = new bytes4[](3);
        hubCoreFactorySelectors[0] = IHubCoreFactory.createPreDepositVault.selector;
        hubCoreFactorySelectors[1] = IHubCoreFactory.createMachineFromPreDeposit.selector;
        hubCoreFactorySelectors[2] = IHubCoreFactory.createMachine.selector;
        deployment.accessManager.setTargetFunctionRole(
            address(deployment.hubCoreFactory), hubCoreFactorySelectors, Roles.STRATEGY_DEPLOYMENT_ROLE
        );

        // SwapModule
        _setupSwapModuleAMFunctionRoles(deployment.accessManager, address(deployment.swapModule));
    }

    function setupSpokeCoreAMFunctionRoles(SpokeCore memory deployment) public {
        // SpokeCoreRegistry
        bytes4[] memory spokeCoreRegistrySelectors = new bytes4[](9);
        spokeCoreRegistrySelectors[0] = ICoreRegistry.setCoreFactory.selector;
        spokeCoreRegistrySelectors[1] = ICoreRegistry.setOracleRegistry.selector;
        spokeCoreRegistrySelectors[2] = ICoreRegistry.setTokenRegistry.selector;
        spokeCoreRegistrySelectors[3] = ICoreRegistry.setSwapModule.selector;
        spokeCoreRegistrySelectors[4] = ICoreRegistry.setFlashLoanModule.selector;
        spokeCoreRegistrySelectors[5] = ICoreRegistry.setCaliberBeacon.selector;
        spokeCoreRegistrySelectors[6] = ICoreRegistry.setBridgeAdapterBeacon.selector;
        spokeCoreRegistrySelectors[7] = ICoreRegistry.setBridgeConfig.selector;
        spokeCoreRegistrySelectors[8] = ISpokeCoreRegistry.setCaliberMailboxBeacon.selector;
        deployment.accessManager.setTargetFunctionRole(
            address(deployment.spokeCoreRegistry), spokeCoreRegistrySelectors, Roles.INFRA_SETUP_ROLE
        );

        // SpokeCoreFactory
        bytes4[] memory spokeCoreFactorySelectors = new bytes4[](1);
        spokeCoreFactorySelectors[0] = ISpokeCoreFactory.createCaliber.selector;
        deployment.accessManager.setTargetFunctionRole(
            address(deployment.spokeCoreFactory), spokeCoreFactorySelectors, Roles.STRATEGY_DEPLOYMENT_ROLE
        );

        // OracleRegistry
        _setupOracleRegistryAMFunctionRoles(deployment.accessManager, address(deployment.oracleRegistry));

        // TokenRegistry
        _setupTokenRegistryAMFunctionRoles(deployment.accessManager, address(deployment.tokenRegistry));

        // SwapModule
        _setupSwapModuleAMFunctionRoles(deployment.accessManager, address(deployment.swapModule));
    }

    ///
    /// ACCESS MANAGER INFRA UTILS
    ///

    function _setupOracleRegistryAMFunctionRoles(AccessManagerUpgradeable accessManager, address _oracleRegistry)
        internal
    {
        bytes4[] memory oracleRegistrySelectors = new bytes4[](2);
        oracleRegistrySelectors[0] = IOracleRegistry.setFeedRoute.selector;
        oracleRegistrySelectors[1] = IOracleRegistry.setFeedStaleThreshold.selector;
        accessManager.setTargetFunctionRole(_oracleRegistry, oracleRegistrySelectors, Roles.INFRA_SETUP_ROLE);
    }

    function _setupTokenRegistryAMFunctionRoles(AccessManagerUpgradeable accessManager, address _tokenRegistry)
        internal
    {
        bytes4[] memory tokenRegistrySelectors = new bytes4[](1);
        tokenRegistrySelectors[0] = ITokenRegistry.setToken.selector;
        accessManager.setTargetFunctionRole(_tokenRegistry, tokenRegistrySelectors, Roles.INFRA_SETUP_ROLE);
    }

    function _setupSwapModuleAMFunctionRoles(AccessManagerUpgradeable accessManager, address _swapModule) internal {
        bytes4[] memory swapModuleSelectors = new bytes4[](1);
        swapModuleSelectors[0] = ISwapModule.setSwapperTargets.selector;
        accessManager.setTargetFunctionRole(_swapModule, swapModuleSelectors, Roles.INFRA_SETUP_ROLE);
    }

    function _setupChainRegistryAMFunctionRoles(AccessManagerUpgradeable accessManager, address _chainRegistry)
        internal
    {
        bytes4[] memory chainRegistrySelectors = new bytes4[](1);
        chainRegistrySelectors[0] = IChainRegistry.setChainIds.selector;
        accessManager.setTargetFunctionRole(_chainRegistry, chainRegistrySelectors, Roles.INFRA_SETUP_ROLE);
    }

    ///
    /// ACCESS MANAGER INSTANCE UTILS
    ///

    function _setupPreDepositVaultAMFunctionRoles(address _accessManager, address _preDepositVault) internal {
        bytes4[] memory mgmtSetupSelectors = new bytes4[](1);
        mgmtSetupSelectors[0] = IMakinaGovernable.setRiskManager.selector;
        IAccessManager(_accessManager).setTargetFunctionRole(
            _preDepositVault, mgmtSetupSelectors, Roles.STRATEGY_MANAGEMENT_SETUP_ROLE
        );
    }

    function _setupMachineAMFunctionRoles(address _accessManager, address _machine) internal {
        bytes4[] memory compSetupSelectors = new bytes4[](6);
        compSetupSelectors[0] = IBridgeController.createBridgeAdapter.selector;
        compSetupSelectors[1] = IMachine.setSpokeCaliber.selector;
        compSetupSelectors[2] = IMachine.setSpokeBridgeAdapter.selector;
        compSetupSelectors[3] = IMachine.setDepositor.selector;
        compSetupSelectors[4] = IMachine.setRedeemer.selector;
        compSetupSelectors[5] = IMachine.setFeeManager.selector;
        IAccessManager(_accessManager).setTargetFunctionRole(
            _machine, compSetupSelectors, Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );

        bytes4[] memory mgmtSetupSelectors = new bytes4[](4);
        mgmtSetupSelectors[0] = IMakinaGovernable.setMechanic.selector;
        mgmtSetupSelectors[1] = IMakinaGovernable.setSecurityCouncil.selector;
        mgmtSetupSelectors[2] = IMakinaGovernable.setRiskManager.selector;
        mgmtSetupSelectors[3] = IMakinaGovernable.setRiskManagerTimelock.selector;
        IAccessManager(_accessManager).setTargetFunctionRole(
            _machine, mgmtSetupSelectors, Roles.STRATEGY_MANAGEMENT_SETUP_ROLE
        );
    }

    function _setupCaliberMailboxAMFunctionRoles(address _accessManager, address _mailbox) internal {
        bytes4[] memory compSetupSelectors = new bytes4[](2);
        compSetupSelectors[0] = IBridgeController.createBridgeAdapter.selector;
        compSetupSelectors[1] = ICaliberMailbox.setHubBridgeAdapter.selector;
        IAccessManager(_accessManager).setTargetFunctionRole(
            _mailbox, compSetupSelectors, Roles.STRATEGY_COMPONENTS_SETUP_ROLE
        );

        bytes4[] memory mgmtSetupSelectors = new bytes4[](4);
        mgmtSetupSelectors[0] = IMakinaGovernable.setMechanic.selector;
        mgmtSetupSelectors[1] = IMakinaGovernable.setSecurityCouncil.selector;
        mgmtSetupSelectors[2] = IMakinaGovernable.setRiskManager.selector;
        mgmtSetupSelectors[3] = IMakinaGovernable.setRiskManagerTimelock.selector;
        IAccessManager(_accessManager).setTargetFunctionRole(
            _mailbox, mgmtSetupSelectors, Roles.STRATEGY_MANAGEMENT_SETUP_ROLE
        );
    }

    function _setupCaliberAMFunctionRoles(address _accessManager, address _caliber) internal {
        bytes4[] memory mgmtSetupSelectors = new bytes4[](2);
        mgmtSetupSelectors[0] = ICaliber.addInstrRootGuardian.selector;
        mgmtSetupSelectors[1] = ICaliber.removeInstrRootGuardian.selector;
        IAccessManager(_accessManager).setTargetFunctionRole(
            _caliber, mgmtSetupSelectors, Roles.STRATEGY_MANAGEMENT_SETUP_ROLE
        );
    }

    function _setupAcrossV3BridgeConfigAMFunctionRoles(address _accessManager, address _acrossV3BridgeConfig)
        internal
    {
        bytes4[] memory acrossV3BridgeConfigSelectors = new bytes4[](1);
        acrossV3BridgeConfigSelectors[0] = IAcrossV3BridgeConfig.setForeignChainSupported.selector;
        IAccessManager(_accessManager).setTargetFunctionRole(
            _acrossV3BridgeConfig, acrossV3BridgeConfigSelectors, Roles.INFRA_SETUP_ROLE
        );
    }

    function _setupLayerZeroV2BridgeConfigAMFunctionRoles(address _accessManager, address _layerZeroV2BridgeConfig)
        internal
    {
        bytes4[] memory layerZeroV2BridgeConfigSelectors = new bytes4[](3);
        layerZeroV2BridgeConfigSelectors[0] = ILayerZeroV2BridgeConfig.setLzChainId.selector;
        layerZeroV2BridgeConfigSelectors[1] = ILayerZeroV2BridgeConfig.setOft.selector;
        layerZeroV2BridgeConfigSelectors[2] = ILayerZeroV2BridgeConfig.setForeignToken.selector;
        IAccessManager(_accessManager).setTargetFunctionRole(
            _layerZeroV2BridgeConfig, layerZeroV2BridgeConfigSelectors, Roles.INFRA_SETUP_ROLE
        );
    }

    ///
    /// DEPLOYMENT UTILS
    ///

    function _deployAccessManager(address _initialAMAdmin, address _proxyOwner)
        internal
        returns (AccessManagerUpgradeable accessManager)
    {
        address implem = _deployCode(type(AccessManagerUpgradeable).creationCode, 0);
        accessManager = AccessManagerUpgradeable(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implem, _proxyOwner, abi.encodeCall(AccessManagerUpgradeable.initialize, (_initialAMAdmin))
                    )
                ),
                ACCESS_MANAGER_SALT_DOMAIN
            )
        );
    }

    function _deployHubCoreRegistry(
        address _proxyOwner,
        address _oracleRegistry,
        address _tokenRegistry,
        address _chainRegistry,
        address _accessManager
    ) internal returns (HubCoreRegistry hubCoreRegistry) {
        address implem = _deployCode(type(HubCoreRegistry).creationCode, 0);
        return HubCoreRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implem,
                        _proxyOwner,
                        abi.encodeCall(
                            HubCoreRegistry.initialize,
                            (_oracleRegistry, _tokenRegistry, _chainRegistry, _accessManager)
                        )
                    )
                ),
                CORE_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deployHubCoreFactory(address _proxyOwner, address _hubCoreRegistry, address _accessManager)
        internal
        returns (HubCoreFactory spokeCoreFactory)
    {
        address implem =
            _deployCode(abi.encodePacked(type(HubCoreFactory).creationCode, abi.encode(_hubCoreRegistry)), 0);
        return HubCoreFactory(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(HubCoreFactory.initialize, (_accessManager)))
                ),
                CORE_FACTORY_SALT_DOMAIN
            )
        );
    }

    function _deploySpokeCoreRegistry(
        address _proxyOwner,
        address _oracleRegistry,
        address _tokenRegistry,
        address _accessManager
    ) internal returns (SpokeCoreRegistry spokeCoreRegistry) {
        address implem = _deployCode(type(SpokeCoreRegistry).creationCode, 0);
        return SpokeCoreRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implem,
                        _proxyOwner,
                        abi.encodeCall(SpokeCoreRegistry.initialize, (_oracleRegistry, _tokenRegistry, _accessManager))
                    )
                ),
                CORE_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deploySpokeCoreFactory(address _proxyOwner, address _spokeCoreRegistry, address _accessManager)
        internal
        returns (SpokeCoreFactory spokeCoreFactory)
    {
        address implem =
            _deployCode(abi.encodePacked(type(SpokeCoreFactory).creationCode, abi.encode(_spokeCoreRegistry)), 0);
        return SpokeCoreFactory(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(SpokeCoreFactory.initialize, (_accessManager)))
                ),
                CORE_FACTORY_SALT_DOMAIN
            )
        );
    }

    function _deployOracleRegistry(address _proxyOwner, address _accessManager)
        internal
        returns (OracleRegistry oracleRegistry)
    {
        address implem = _deployCode(type(OracleRegistry).creationCode, 0);
        oracleRegistry = OracleRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(OracleRegistry.initialize, (_accessManager)))
                ),
                ORACLE_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deployChainRegistry(address _proxyOwner, address _accessManager)
        internal
        returns (ChainRegistry tokenRegistry)
    {
        address implem = _deployCode(type(ChainRegistry).creationCode, 0);
        tokenRegistry = ChainRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(ChainRegistry.initialize, (_accessManager)))
                ),
                CHAIN_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deployTokenRegistry(address _proxyOwner, address _accessManager)
        internal
        returns (TokenRegistry tokenRegistry)
    {
        address implem = _deployCode(type(TokenRegistry).creationCode, 0);
        tokenRegistry = TokenRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(TokenRegistry.initialize, (_accessManager)))
                ),
                TOKEN_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deploySwapModule(address _proxyOwner, address _coreRegistry, address _accessManager)
        internal
        returns (SwapModule swapModule)
    {
        address implem = _deployCode(abi.encodePacked(type(SwapModule).creationCode, abi.encode(_coreRegistry)), 0);
        swapModule = SwapModule(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(SwapModule.initialize, (_accessManager)))
                ),
                SWAP_MODULE_SALT_DOMAIN
            )
        );
    }

    function _deployWeirollVM() internal returns (address weirollVM) {
        return _deployCode(getWeirollVMCode(), WEIROLL_VM_SALT_DOMAIN);
    }

    function _deployMachineBeacon(address _proxyOwner, address _hubCoreRegistry, address _wormhole)
        internal
        returns (UpgradeableBeacon caliberBeacon)
    {
        address implem =
            _deployCode(abi.encodePacked(type(Machine).creationCode, abi.encode(_hubCoreRegistry, _wormhole)), 0);
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _proxyOwner)),
                MACHINE_BEACON_SALT_DOMAIN
            )
        );
    }

    function _deployPreDepositVaultBeacon(address _proxyOwner, address _hubCoreRegistry)
        internal
        returns (UpgradeableBeacon preDepositVaultBeacon)
    {
        address implem =
            _deployCode(abi.encodePacked(type(PreDepositVault).creationCode, abi.encode(_hubCoreRegistry)), 0);
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _proxyOwner)),
                PRE_DEPOSIT_VAULT_SALT_DOMAIN
            )
        );
    }

    function _deployCaliberBeacon(address _proxyOwner, address _coreRegistry, address _weirollVM)
        internal
        returns (UpgradeableBeacon caliberBeacon)
    {
        address implem =
            _deployCode(abi.encodePacked(type(Caliber).creationCode, abi.encode(_coreRegistry, _weirollVM)), 0);
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _proxyOwner)),
                CALIBER_BEACON_SALT_DOMAIN
            )
        );
    }

    function _deployCaliberMailboxBeacon(address _proxyOwner, address _spokeCoreRegistry, uint256 _hubChainId)
        internal
        returns (UpgradeableBeacon caliberMailboxBeacon)
    {
        address implem = _deployCode(
            abi.encodePacked(type(CaliberMailbox).creationCode, abi.encode(_spokeCoreRegistry, _hubChainId)), 0
        );
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _proxyOwner)),
                CALIBER_MAILBOX_BEACON_SALT_DOMAIN
            )
        );
    }

    function _deployAcrossV3BridgeConfig(address _proxyOwner, address _accessManager)
        internal
        returns (AcrossV3BridgeConfig acrossV3BridgeConfig)
    {
        address implem = _deployCode(type(AcrossV3BridgeConfig).creationCode, 0);
        return AcrossV3BridgeConfig(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _proxyOwner, abi.encodeCall(AcrossV3BridgeConfig.initialize, (_accessManager)))
                ),
                ACROSS_V3_BRIDGE_CONFIG_SALT_DOMAIN
            )
        );
    }

    function _deployAcrossV3BridgeAdapterBeacon(address _beaconOwner, address _coreRegistry, address _acrossV3SpokePool)
        internal
        returns (UpgradeableBeacon acrossV3BridgeAdapterBeacon)
    {
        address implem = _deployCode(
            abi.encodePacked(type(AcrossV3BridgeAdapter).creationCode, abi.encode(_coreRegistry, _acrossV3SpokePool)), 0
        );
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _beaconOwner)),
                ACROSS_V3_BRIDGE_ADAPTER_SALT_DOMAIN
            )
        );
    }

    function _deployLayerZeroV2BridgeConfig(address _proxyOwner, address _accessManager)
        internal
        returns (LayerZeroV2BridgeConfig layerZeroV2BridgeConfig)
    {
        address implem = _deployCode(type(LayerZeroV2BridgeConfig).creationCode, 0);
        return LayerZeroV2BridgeConfig(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implem, _proxyOwner, abi.encodeCall(LayerZeroV2BridgeConfig.initialize, (_accessManager))
                    )
                ),
                LAYER_ZERO_V2_CONFIG_SALT_DOMAIN
            )
        );
    }

    function _deployLayerZeroV2BridgeAdapterBeacon(
        address _beaconOwner,
        address _coreRegistry,
        address _layerZeroEndpoint
    ) internal returns (UpgradeableBeacon layerZeroV2BridgeAdapterBeacon) {
        address implem = _deployCode(
            abi.encodePacked(type(LayerZeroV2BridgeAdapter).creationCode, abi.encode(_coreRegistry, _layerZeroEndpoint)),
            0
        );
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _beaconOwner)),
                LAYER_ZERO_V2_BRIDGE_ADAPTER_SALT_DOMAIN
            )
        );
    }

    function _deployCode(bytes memory bytecode, bytes32) internal virtual returns (address) {
        address addr;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        require(addr != address(0), "Deployment failed");

        return addr;
    }
}
