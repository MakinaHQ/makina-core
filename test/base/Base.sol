// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {AcrossV3BridgeAdapter} from "../../src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {ChainsInfo} from "../utils/ChainsInfo.sol";
import {Caliber} from "../../src/caliber/Caliber.sol";
import {SpokeCoreFactory} from "../../src/factories/SpokeCoreFactory.sol";
import {CaliberMailbox} from "../../src/caliber/CaliberMailbox.sol";
import {ChainRegistry} from "../../src/registries/ChainRegistry.sol";
import {HubCoreRegistry} from "../../src/registries/HubCoreRegistry.sol";
import {IBridgeController} from "../../src/interfaces/IBridgeController.sol";
import {ICaliberMailbox} from "../../src/interfaces/ICaliberMailbox.sol";
import {IChainRegistry} from "../../src/interfaces/IChainRegistry.sol";
import {ICoreRegistry} from "../../src/interfaces/ICoreRegistry.sol";
import {IHubCoreFactory} from "../../src/interfaces/IHubCoreFactory.sol";
import {IHubCoreRegistry} from "../../src/interfaces/IHubCoreRegistry.sol";
import {IOracleRegistry} from "../../src/interfaces/IOracleRegistry.sol";
import {IRCodeReader} from "../utils/IRCodeReader.sol";
import {ISpokeCoreFactory} from "../../src/interfaces/ISpokeCoreFactory.sol";
import {ISpokeCoreRegistry} from "../../src/interfaces/ISpokeCoreRegistry.sol";
import {ISwapModule} from "../../src/interfaces/ISwapModule.sol";
import {ITokenRegistry} from "../../src/interfaces/ITokenRegistry.sol";
import {IMachine} from "../../src/interfaces/IMachine.sol";
import {Machine} from "../../src/machine/Machine.sol";
import {HubCoreFactory} from "../../src/factories/HubCoreFactory.sol";
import {OracleRegistry} from "../../src/registries/OracleRegistry.sol";
import {PreDepositVault} from "../../src/pre-deposit/PreDepositVault.sol";
import {Roles} from "../utils/Roles.sol";
import {SaltDomains} from "../utils/SaltDomains.sol";
import {SpokeCoreRegistry} from "../../src/registries/SpokeCoreRegistry.sol";
import {SwapModule} from "../../src/swap/SwapModule.sol";
import {TokenRegistry} from "../../src/registries/TokenRegistry.sol";

abstract contract Base is IRCodeReader, SaltDomains {
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

    function deployHubCore(address initialAMAdmin, address dao, address wormhole)
        internal
        returns (HubCore memory deployment)
    {
        // Access Manager
        deployment.accessManager = _deployAccessManager(initialAMAdmin, dao);

        // Oracle Registry
        deployment.oracleRegistry = _deployOracleRegistry(dao, address(deployment.accessManager));

        // Token Registry
        deployment.tokenRegistry = _deployTokenRegistry(dao, address(deployment.accessManager));

        // Chain Registry
        deployment.chainRegistry = _deployChainRegistry(dao, address(deployment.accessManager));

        // Hub Core Registry
        deployment.hubCoreRegistry = _deployHubCoreRegistry(
            dao,
            address(deployment.oracleRegistry),
            address(deployment.tokenRegistry),
            address(deployment.chainRegistry),
            address(deployment.accessManager)
        );

        // Hub Core Factory
        deployment.hubCoreFactory =
            _deployHubCoreFactory(dao, address(deployment.hubCoreRegistry), address(deployment.accessManager));

        // Swap Module
        deployment.swapModule =
            _deploySwapModule(dao, address(deployment.hubCoreRegistry), address(deployment.accessManager));

        // Weiroll VM
        address weirollVM = _deployWeirollVM();

        // Caliber Beacon
        deployment.caliberBeacon = _deployCaliberBeacon(dao, address(deployment.hubCoreRegistry), weirollVM);

        // Machine Beacon
        deployment.machineBeacon = _deployMachineBeacon(dao, address(deployment.hubCoreRegistry), wormhole);

        // PreDeposit Vault Beacon
        deployment.preDepositVaultBeacon = _deployPreDepositVaultBeacon(dao, address(deployment.hubCoreRegistry));
    }

    function deploySpokeCore(address initialAMAdmin, address dao, uint256 hubChainId)
        internal
        returns (SpokeCore memory deployment)
    {
        // Access Manager
        deployment.accessManager = _deployAccessManager(initialAMAdmin, dao);

        // Oracle Registry
        deployment.oracleRegistry = _deployOracleRegistry(dao, address(deployment.accessManager));

        // Token Registry
        deployment.tokenRegistry = _deployTokenRegistry(dao, address(deployment.accessManager));

        // Spoke Core Registry
        deployment.spokeCoreRegistry = _deploySpokeCoreRegistry(
            dao,
            address(deployment.oracleRegistry),
            address(deployment.tokenRegistry),
            address(deployment.accessManager)
        );

        // Spoke Core Factory
        deployment.spokeCoreFactory =
            _deploySpokeCoreFactory(dao, address(deployment.spokeCoreRegistry), address(deployment.accessManager));

        // Swap Module
        deployment.swapModule =
            _deploySwapModule(dao, address(deployment.spokeCoreRegistry), address(deployment.accessManager));

        // Weiroll VM
        address weirollVM = _deployWeirollVM();

        // Caliber Beacon
        deployment.caliberBeacon = _deployCaliberBeacon(dao, address(deployment.spokeCoreRegistry), weirollVM);

        // Caliber Mailbox Beacon
        deployment.caliberMailboxBeacon =
            _deployCaliberMailboxBeacon(dao, address(deployment.spokeCoreRegistry), hubChainId);
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

    function deployAndSetupBridgeAdapterBeacons(
        ICoreRegistry makinaRegistry,
        BridgeData[] memory bridgesData,
        address dao
    ) public returns (UpgradeableBeacon[] memory bridgeAdapterBeacons) {
        bridgeAdapterBeacons = new UpgradeableBeacon[](bridgesData.length);
        for (uint256 i; i < bridgesData.length; i++) {
            uint16 bridgeId = bridgesData[i].bridgeId;
            UpgradeableBeacon baBeacon;
            if (bridgeId == 1) {
                baBeacon = _deployAcrossV3BridgeAdapterBeacon(dao, bridgesData[i].executionTarget);
            } else {
                revert("Bridge not supported");
            }
            bridgeAdapterBeacons[i] = baBeacon;
            makinaRegistry.setBridgeAdapterBeacon(bridgeId, address(baBeacon));
        }
    }

    ///
    /// ACCESS MANAGER SETUP
    ///

    function setupAccessManagerRoles(AccessManagerUpgradeable accessManager, address dao, address deployer) public {
        // Grant roles to the DAO
        accessManager.grantRole(accessManager.ADMIN_ROLE(), dao, 0);
        accessManager.grantRole(Roles.STRATEGY_DEPLOYER_ROLE, dao, 0);
        accessManager.grantRole(Roles.STRATEGY_CONFIG_ROLE, dao, 0);
        accessManager.grantRole(Roles.INFRA_CONFIG_ROLE, dao, 0);

        // Revoke roles from the deployer
        accessManager.revokeRole(accessManager.ADMIN_ROLE(), address(deployer));
    }

    function setupHubCoreAMFunctionRoles(HubCore memory deployment) public {
        // HubCoreRegistry
        bytes4[] memory hubCoreRegistrySelectors = new bytes4[](10);
        hubCoreRegistrySelectors[0] = ICoreRegistry.setCoreFactory.selector;
        hubCoreRegistrySelectors[1] = ICoreRegistry.setOracleRegistry.selector;
        hubCoreRegistrySelectors[2] = ICoreRegistry.setTokenRegistry.selector;
        hubCoreRegistrySelectors[3] = ICoreRegistry.setSwapModule.selector;
        hubCoreRegistrySelectors[4] = ICoreRegistry.setFlashLoanModule.selector;
        hubCoreRegistrySelectors[5] = ICoreRegistry.setCaliberBeacon.selector;
        hubCoreRegistrySelectors[6] = ICoreRegistry.setBridgeAdapterBeacon.selector;
        hubCoreRegistrySelectors[7] = IHubCoreRegistry.setChainRegistry.selector;
        hubCoreRegistrySelectors[8] = IHubCoreRegistry.setMachineBeacon.selector;
        hubCoreRegistrySelectors[9] = IHubCoreRegistry.setPreDepositVaultBeacon.selector;
        deployment.accessManager.setTargetFunctionRole(
            address(deployment.hubCoreRegistry), hubCoreRegistrySelectors, Roles.INFRA_CONFIG_ROLE
        );

        // ChainRegistry
        _setupChainRegistryAMFunctionRoles(deployment.accessManager, address(deployment.chainRegistry));

        // HubCoreFactory
        bytes4[] memory hubCoreFactorySelectors = new bytes4[](3);
        hubCoreFactorySelectors[0] = IHubCoreFactory.createPreDepositVault.selector;
        hubCoreFactorySelectors[1] = IHubCoreFactory.createMachineFromPreDeposit.selector;
        hubCoreFactorySelectors[2] = IHubCoreFactory.createMachine.selector;
        deployment.accessManager.setTargetFunctionRole(
            address(deployment.hubCoreFactory), hubCoreFactorySelectors, Roles.STRATEGY_DEPLOYER_ROLE
        );

        // OracleRegistry
        _setupOracleRegistryAMFunctionRoles(deployment.accessManager, address(deployment.oracleRegistry));

        // TokenRegistry
        _setupTokenRegistryAMFunctionRoles(deployment.accessManager, address(deployment.tokenRegistry));

        // SwapModule
        _setupSwapModuleAMFunctionRoles(deployment.accessManager, address(deployment.swapModule));
    }

    function setupSpokeCoreAMFunctionRoles(SpokeCore memory deployment) public {
        // SpokeCoreRegistry
        bytes4[] memory spokeCoreRegistrySelectors = new bytes4[](8);
        spokeCoreRegistrySelectors[0] = ICoreRegistry.setCoreFactory.selector;
        spokeCoreRegistrySelectors[1] = ICoreRegistry.setOracleRegistry.selector;
        spokeCoreRegistrySelectors[2] = ICoreRegistry.setTokenRegistry.selector;
        spokeCoreRegistrySelectors[3] = ICoreRegistry.setSwapModule.selector;
        spokeCoreRegistrySelectors[4] = ICoreRegistry.setFlashLoanModule.selector;
        spokeCoreRegistrySelectors[5] = ICoreRegistry.setCaliberBeacon.selector;
        spokeCoreRegistrySelectors[6] = ICoreRegistry.setBridgeAdapterBeacon.selector;
        spokeCoreRegistrySelectors[7] = ISpokeCoreRegistry.setCaliberMailboxBeacon.selector;
        deployment.accessManager.setTargetFunctionRole(
            address(deployment.spokeCoreRegistry), spokeCoreRegistrySelectors, Roles.INFRA_CONFIG_ROLE
        );

        // SpokeCoreFactory
        bytes4[] memory spokeCoreFactorySelectors = new bytes4[](1);
        spokeCoreFactorySelectors[0] = ISpokeCoreFactory.createCaliber.selector;
        deployment.accessManager.setTargetFunctionRole(
            address(deployment.spokeCoreFactory), spokeCoreFactorySelectors, Roles.STRATEGY_DEPLOYER_ROLE
        );

        // OracleRegistry
        _setupOracleRegistryAMFunctionRoles(deployment.accessManager, address(deployment.oracleRegistry));

        // TokenRegistry
        _setupTokenRegistryAMFunctionRoles(deployment.accessManager, address(deployment.tokenRegistry));

        // SwapModule
        _setupSwapModuleAMFunctionRoles(deployment.accessManager, address(deployment.swapModule));
    }

    function _setupOracleRegistryAMFunctionRoles(AccessManagerUpgradeable accessManager, address _oracleRegistry)
        internal
    {
        bytes4[] memory oracleRegistrySelectors = new bytes4[](2);
        oracleRegistrySelectors[0] = IOracleRegistry.setFeedRoute.selector;
        oracleRegistrySelectors[1] = IOracleRegistry.setFeedStaleThreshold.selector;
        accessManager.setTargetFunctionRole(_oracleRegistry, oracleRegistrySelectors, Roles.INFRA_CONFIG_ROLE);
    }

    function _setupTokenRegistryAMFunctionRoles(AccessManagerUpgradeable accessManager, address _tokenRegistry)
        internal
    {
        bytes4[] memory tokenRegistrySelectors = new bytes4[](1);
        tokenRegistrySelectors[0] = ITokenRegistry.setToken.selector;
        accessManager.setTargetFunctionRole(_tokenRegistry, tokenRegistrySelectors, Roles.INFRA_CONFIG_ROLE);
    }

    function _setupSwapModuleAMFunctionRoles(AccessManagerUpgradeable accessManager, address _swapModule) internal {
        bytes4[] memory swapModuleSelectors = new bytes4[](1);
        swapModuleSelectors[0] = ISwapModule.setSwapperTargets.selector;
        accessManager.setTargetFunctionRole(_swapModule, swapModuleSelectors, Roles.INFRA_CONFIG_ROLE);
    }

    function _setupChainRegistryAMFunctionRoles(AccessManagerUpgradeable accessManager, address _chainRegistry)
        internal
    {
        bytes4[] memory chainRegistrySelectors = new bytes4[](1);
        chainRegistrySelectors[0] = IChainRegistry.setChainIds.selector;
        accessManager.setTargetFunctionRole(_chainRegistry, chainRegistrySelectors, Roles.INFRA_CONFIG_ROLE);
    }

    function _setupMachineAMFunctionRoles(AccessManagerUpgradeable accessManager, address _machine) internal {
        bytes4[] memory machineSelectors = new bytes4[](9);
        machineSelectors[0] = IBridgeController.createBridgeAdapter.selector;
        machineSelectors[1] = IBridgeController.resetBridgingState.selector;
        machineSelectors[2] = IMachine.setSpokeCaliber.selector;
        machineSelectors[3] = IMachine.setSpokeBridgeAdapter.selector;
        machineSelectors[4] = IMachine.setDepositor.selector;
        machineSelectors[5] = IMachine.setRedeemer.selector;
        machineSelectors[6] = IMachine.setFeeManager.selector;
        machineSelectors[7] = IMachine.setMaxFeeAccrualRate.selector;
        machineSelectors[8] = IMachine.setFeeMintCooldown.selector;
        accessManager.setTargetFunctionRole(_machine, machineSelectors, Roles.STRATEGY_CONFIG_ROLE);
    }

    function _setupCaliberMailboxAMFunctionRoles(AccessManagerUpgradeable accessManager, address _mailbox) internal {
        bytes4[] memory mailboxSelectors = new bytes4[](3);
        mailboxSelectors[0] = IBridgeController.createBridgeAdapter.selector;
        mailboxSelectors[1] = IBridgeController.resetBridgingState.selector;
        mailboxSelectors[2] = ICaliberMailbox.setHubBridgeAdapter.selector;
        accessManager.setTargetFunctionRole(_mailbox, mailboxSelectors, Roles.STRATEGY_CONFIG_ROLE);
    }

    ///
    /// DEPLOYMENT UTILS
    ///

    function _deployAccessManager(address _initialAMAdmin, address _dao)
        internal
        returns (AccessManagerUpgradeable accessManager)
    {
        address implem = _deployCode(type(AccessManagerUpgradeable).creationCode, 0);
        accessManager = AccessManagerUpgradeable(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _dao, abi.encodeCall(AccessManagerUpgradeable.initialize, (_initialAMAdmin)))
                ),
                ACCESS_MANAGER_SALT_DOMAIN
            )
        );
    }

    function _deployHubCoreRegistry(
        address _dao,
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
                        _dao,
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

    function _deployHubCoreFactory(address _dao, address _hubCoreRegistry, address _accessManager)
        internal
        returns (HubCoreFactory spokeCoreFactory)
    {
        address implem =
            _deployCode(abi.encodePacked(type(HubCoreFactory).creationCode, abi.encode(_hubCoreRegistry)), 0);
        return HubCoreFactory(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _dao, abi.encodeCall(HubCoreFactory.initialize, (_accessManager)))
                ),
                CORE_FACTORY_SALT_DOMAIN
            )
        );
    }

    function _deploySpokeCoreRegistry(
        address _dao,
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
                        _dao,
                        abi.encodeCall(SpokeCoreRegistry.initialize, (_oracleRegistry, _tokenRegistry, _accessManager))
                    )
                ),
                CORE_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deploySpokeCoreFactory(address _dao, address _spokeCoreRegistry, address _accessManager)
        internal
        returns (SpokeCoreFactory spokeCoreFactory)
    {
        address implem =
            _deployCode(abi.encodePacked(type(SpokeCoreFactory).creationCode, abi.encode(_spokeCoreRegistry)), 0);
        return SpokeCoreFactory(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _dao, abi.encodeCall(SpokeCoreFactory.initialize, (_accessManager)))
                ),
                CORE_FACTORY_SALT_DOMAIN
            )
        );
    }

    function _deployOracleRegistry(address _dao, address _accessManager)
        internal
        returns (OracleRegistry oracleRegistry)
    {
        address implem = _deployCode(type(OracleRegistry).creationCode, 0);
        oracleRegistry = OracleRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _dao, abi.encodeCall(OracleRegistry.initialize, (_accessManager)))
                ),
                ORACLE_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deployChainRegistry(address _dao, address _accessManager)
        internal
        returns (ChainRegistry tokenRegistry)
    {
        address implem = _deployCode(type(ChainRegistry).creationCode, 0);
        tokenRegistry = ChainRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _dao, abi.encodeCall(ChainRegistry.initialize, (_accessManager)))
                ),
                CHAIN_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deployTokenRegistry(address _dao, address _accessManager)
        internal
        returns (TokenRegistry tokenRegistry)
    {
        address implem = _deployCode(type(TokenRegistry).creationCode, 0);
        tokenRegistry = TokenRegistry(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _dao, abi.encodeCall(TokenRegistry.initialize, (_accessManager)))
                ),
                TOKEN_REGISTRY_SALT_DOMAIN
            )
        );
    }

    function _deploySwapModule(address _dao, address _coreRegistry, address _accessManager)
        internal
        returns (SwapModule swapModule)
    {
        address implem = _deployCode(abi.encodePacked(type(SwapModule).creationCode, abi.encode(_coreRegistry)), 0);
        swapModule = SwapModule(
            _deployCode(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implem, _dao, abi.encodeCall(SwapModule.initialize, (_accessManager)))
                ),
                SWAP_MODULE_SALT_DOMAIN
            )
        );
    }

    function _deployWeirollVM() internal returns (address weirollVM) {
        return _deployCode(getWeirollVMCode(), WEIROLL_VM_SALT_DOMAIN);
    }

    function _deployMachineBeacon(address _dao, address _hubCoreRegistry, address _wormhole)
        internal
        returns (UpgradeableBeacon caliberBeacon)
    {
        address implem =
            _deployCode(abi.encodePacked(type(Machine).creationCode, abi.encode(_hubCoreRegistry, _wormhole)), 0);
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _dao)),
                MACHINE_BEACON_SALT_DOMAIN
            )
        );
    }

    function _deployPreDepositVaultBeacon(address _dao, address _hubCoreRegistry)
        internal
        returns (UpgradeableBeacon preDepositVaultBeacon)
    {
        address implem =
            _deployCode(abi.encodePacked(type(PreDepositVault).creationCode, abi.encode(_hubCoreRegistry)), 0);
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _dao)),
                PRE_DEPOSIT_VAULT_SALT_DOMAIN
            )
        );
    }

    function _deployCaliberBeacon(address _dao, address _coreRegistry, address _weirollVM)
        internal
        returns (UpgradeableBeacon caliberBeacon)
    {
        address implem =
            _deployCode(abi.encodePacked(type(Caliber).creationCode, abi.encode(_coreRegistry, _weirollVM)), 0);
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _dao)),
                CALIBER_BEACON_SALT_DOMAIN
            )
        );
    }

    function _deployCaliberMailboxBeacon(address _dao, address _spokeCoreRegistry, uint256 _hubChainId)
        internal
        returns (UpgradeableBeacon caliberMailboxBeacon)
    {
        address implem = _deployCode(
            abi.encodePacked(type(CaliberMailbox).creationCode, abi.encode(_spokeCoreRegistry, _hubChainId)), 0
        );
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _dao)),
                CALIBER_MAILBOX_BEACON_SALT_DOMAIN
            )
        );
    }

    function _deployAcrossV3BridgeAdapterBeacon(address _dao, address _acrossV3SpokePool)
        internal
        returns (UpgradeableBeacon acrossV3BridgeAdapterBeacon)
    {
        address implem =
            _deployCode(abi.encodePacked(type(AcrossV3BridgeAdapter).creationCode, abi.encode(_acrossV3SpokePool)), 0);
        return UpgradeableBeacon(
            _deployCode(
                abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implem, _dao)),
                ACROSS_V3_BRIDGE_ADAPTER_SALT_DOMAIN
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
