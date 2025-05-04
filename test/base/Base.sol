// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {AcrossV3BridgeAdapter} from "src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {ChainsInfo} from "../utils/ChainsInfo.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {SpokeCoreFactory} from "src/factories/SpokeCoreFactory.sol";
import {CaliberMailbox} from "src/caliber/CaliberMailbox.sol";
import {ChainRegistry} from "src/registries/ChainRegistry.sol";
import {DeployViaIr} from "../utils/DeployViaIR.sol";
import {HubCoreRegistry} from "src/registries/HubCoreRegistry.sol";
import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";
import {Machine} from "src/machine/Machine.sol";
import {HubCoreFactory} from "src/factories/HubCoreFactory.sol";
import {OracleRegistry} from "src/registries/OracleRegistry.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";
import {SpokeCoreRegistry} from "src/registries/SpokeCoreRegistry.sol";
import {SwapModule} from "src/swap/SwapModule.sol";
import {TokenRegistry} from "src/registries/TokenRegistry.sol";

abstract contract Base is DeployViaIr {
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

    function deploySharedCore(address initialAMAdmin, address dao)
        public
        returns (AccessManagerUpgradeable accessManager, OracleRegistry oracleRegistry, TokenRegistry tokenRegistry)
    {
        address accessManagerImplemAddr = address(new AccessManagerUpgradeable());
        accessManager = AccessManagerUpgradeable(
            address(
                new TransparentUpgradeableProxy(
                    accessManagerImplemAddr, dao, abi.encodeCall(AccessManagerUpgradeable.initialize, (initialAMAdmin))
                )
            )
        );

        address oracleRegistryImplemAddr = address(new OracleRegistry());
        oracleRegistry = OracleRegistry(
            address(
                new TransparentUpgradeableProxy(
                    oracleRegistryImplemAddr, dao, abi.encodeCall(OracleRegistry.initialize, (address(accessManager)))
                )
            )
        );

        address tokenRegistryImplemAddr = address(new TokenRegistry());
        tokenRegistry = TokenRegistry(
            address(
                new TransparentUpgradeableProxy(
                    tokenRegistryImplemAddr, dao, abi.encodeCall(TokenRegistry.initialize, (address(accessManager)))
                )
            )
        );
    }

    function deployHubCore(address initialAMAdmin, address dao, address wormhole)
        internal
        returns (HubCore memory deployment)
    {
        (deployment.accessManager, deployment.oracleRegistry, deployment.tokenRegistry) =
            deploySharedCore(initialAMAdmin, dao);

        address chainRegistryImplemAddr = address(new ChainRegistry());
        deployment.chainRegistry = ChainRegistry(
            address(
                new TransparentUpgradeableProxy(
                    chainRegistryImplemAddr,
                    dao,
                    abi.encodeCall(ChainRegistry.initialize, (address(deployment.accessManager)))
                )
            )
        );

        address hubCoreRegistryImplemAddr = address(new HubCoreRegistry());
        deployment.hubCoreRegistry = HubCoreRegistry(
            address(
                new TransparentUpgradeableProxy(
                    hubCoreRegistryImplemAddr,
                    dao,
                    abi.encodeCall(
                        HubCoreRegistry.initialize,
                        (
                            address(deployment.oracleRegistry),
                            address(deployment.tokenRegistry),
                            address(deployment.chainRegistry),
                            address(deployment.accessManager)
                        )
                    )
                )
            )
        );

        address swapModuleImplemAddr = address(new SwapModule(address(deployment.hubCoreRegistry)));
        deployment.swapModule = SwapModule(
            address(
                new TransparentUpgradeableProxy(
                    swapModuleImplemAddr,
                    dao,
                    abi.encodeCall(SwapModule.initialize, (address(deployment.accessManager)))
                )
            )
        );

        address weirollVMImplemAddr = DeployViaIr.deployWeirollVMViaIR();
        address caliberImplemAddr = address(new Caliber(address(deployment.hubCoreRegistry), weirollVMImplemAddr));
        deployment.caliberBeacon = new UpgradeableBeacon(caliberImplemAddr, dao);

        address machineImplemAddr = address(new Machine(address(deployment.hubCoreRegistry), wormhole));
        deployment.machineBeacon = new UpgradeableBeacon(machineImplemAddr, dao);

        address preDepositVaultImplemAddr = address(new PreDepositVault(address(deployment.hubCoreRegistry)));
        deployment.preDepositVaultBeacon = new UpgradeableBeacon(preDepositVaultImplemAddr, dao);

        address hubCoreFactoryImplemAddr = address(new HubCoreFactory(address(deployment.hubCoreRegistry)));
        deployment.hubCoreFactory = HubCoreFactory(
            address(
                new TransparentUpgradeableProxy(
                    hubCoreFactoryImplemAddr,
                    dao,
                    abi.encodeCall(HubCoreFactory.initialize, (address(deployment.accessManager)))
                )
            )
        );
    }

    function deploySpokeCore(address initialAMAdmin, address dao, uint256 hubChainId)
        internal
        returns (SpokeCore memory deployment)
    {
        (deployment.accessManager, deployment.oracleRegistry, deployment.tokenRegistry) =
            deploySharedCore(initialAMAdmin, dao);

        deployment.spokeCoreRegistry = _deploySpokeCoreRegistry(
            dao,
            address(deployment.oracleRegistry),
            address(deployment.tokenRegistry),
            address(deployment.accessManager)
        );

        address swapModuleImplemAddr = address(new SwapModule(address(deployment.spokeCoreRegistry)));
        deployment.swapModule = SwapModule(
            address(
                new TransparentUpgradeableProxy(
                    swapModuleImplemAddr,
                    dao,
                    abi.encodeCall(SwapModule.initialize, (address(deployment.accessManager)))
                )
            )
        );

        address weirollVMImplemAddr = deployWeirollVMViaIR();
        address caliberImplemAddr = address(new Caliber(address(deployment.spokeCoreRegistry), weirollVMImplemAddr));
        deployment.caliberBeacon = new UpgradeableBeacon(caliberImplemAddr, dao);

        deployment.spokeCoreFactory =
            _deploySpokeCoreFactory(dao, address(deployment.spokeCoreRegistry), address(deployment.accessManager));

        deployment.caliberMailboxBeacon =
            _deployCaliberMailboxBeacon(dao, address(deployment.spokeCoreRegistry), hubChainId);
    }

    ///
    /// REGISTRIES SETUP
    ///

    function setupHubCoreRegistry(HubCore memory deployment) public {
        deployment.hubCoreRegistry.setSwapModule(address(deployment.swapModule));
        deployment.hubCoreRegistry.setTokenRegistry(address(deployment.tokenRegistry));
        deployment.hubCoreRegistry.setChainRegistry(address(deployment.chainRegistry));
        deployment.hubCoreRegistry.setCoreFactory(address(deployment.hubCoreFactory));
        deployment.hubCoreRegistry.setCaliberBeacon(address(deployment.caliberBeacon));
        deployment.hubCoreRegistry.setMachineBeacon(address(deployment.machineBeacon));
        deployment.hubCoreRegistry.setPreDepositVaultBeacon(address(deployment.preDepositVaultBeacon));
    }

    function setupSpokeCoreRegistry(SpokeCore memory deployment) public {
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

    function deployAndSetupBridgeAdapterBeacon(
        ICoreRegistry makinaRegistry,
        BridgeData[] memory bridgesData,
        address dao
    ) public {
        for (uint256 i; i < bridgesData.length; i++) {
            uint16 bridgeId = bridgesData[i].bridgeId;
            address baBeacon;
            if (bridgeId == 1) {
                baBeacon = address(_deployAcrossV3BridgeAdapterBeacon(dao, bridgesData[i].executionTarget));
            } else {
                revert("Bridge not supported");
            }
            makinaRegistry.setBridgeAdapterBeacon(bridgeId, baBeacon);
        }
    }

    ///
    /// ACCESS MANAGER SETUP
    ///

    function setupAccessManager(AccessManagerUpgradeable accessManager, address dao) public {
        accessManager.grantRole(accessManager.ADMIN_ROLE(), dao, 0);
        accessManager.revokeRole(accessManager.ADMIN_ROLE(), address(this));
    }

    ///
    /// DEPLOYMENT UTILS
    ///

    function _deploySpokeCoreRegistry(
        address _dao,
        address _oracleRegistry,
        address _tokenRegistry,
        address _accessManager
    ) internal returns (SpokeCoreRegistry spokeCoreRegistry) {
        address spokeCoreRegistryImplemAddr = address(new SpokeCoreRegistry());
        return SpokeCoreRegistry(
            address(
                new TransparentUpgradeableProxy(
                    spokeCoreRegistryImplemAddr,
                    _dao,
                    abi.encodeCall(SpokeCoreRegistry.initialize, (_oracleRegistry, _tokenRegistry, _accessManager))
                )
            )
        );
    }

    function _deploySpokeCoreFactory(address _dao, address _spokeCoreRegistry, address _accessManager)
        internal
        returns (SpokeCoreFactory spokeCoreFactory)
    {
        address spokeCoreFactoryImplemAddr = address(new SpokeCoreFactory(_spokeCoreRegistry));
        return SpokeCoreFactory(
            address(
                new TransparentUpgradeableProxy(
                    spokeCoreFactoryImplemAddr, _dao, abi.encodeCall(SpokeCoreFactory.initialize, (_accessManager))
                )
            )
        );
    }

    function _deployCaliberMailboxBeacon(address _dao, address _spokeCoreRegistry, uint256 _hubChainId)
        internal
        returns (UpgradeableBeacon caliberMailboxBeacon)
    {
        address caliberMailboxImplemAddr = address(new CaliberMailbox(_spokeCoreRegistry, _hubChainId));
        caliberMailboxBeacon = new UpgradeableBeacon(caliberMailboxImplemAddr, _dao);
    }

    function _deployAcrossV3BridgeAdapterBeacon(address _dao, address _acrossV3SpokePool)
        internal
        returns (UpgradeableBeacon acrossV3BridgeAdapterBeacon)
    {
        address acrossV3BridgeAdapterImplemAddr = address(new AcrossV3BridgeAdapter(_acrossV3SpokePool));
        return UpgradeableBeacon(address(new UpgradeableBeacon(acrossV3BridgeAdapterImplemAddr, _dao)));
    }
}
