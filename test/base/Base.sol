// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {AcrossV3BridgeAdapter} from "src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {ChainsInfo} from "../utils/ChainsInfo.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {CaliberFactory} from "src/factories/CaliberFactory.sol";
import {CaliberMailbox} from "src/caliber/CaliberMailbox.sol";
import {ChainRegistry} from "src/registries/ChainRegistry.sol";
import {DeployViaIr} from "../utils/DeployViaIR.sol";
import {HubCoreRegistry} from "src/registries/HubCoreRegistry.sol";
import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";
import {Machine} from "src/machine/Machine.sol";
import {MachineFactory} from "src/factories/MachineFactory.sol";
import {OracleRegistry} from "src/registries/OracleRegistry.sol";
import {PreDepositVault} from "src/pre-deposit/PreDepositVault.sol";
import {SpokeCoreRegistry} from "src/registries/SpokeCoreRegistry.sol";
import {SwapModule} from "src/swap/SwapModule.sol";
import {TokenRegistry} from "src/registries/TokenRegistry.sol";

abstract contract Base is DeployViaIr {
    struct HubCore {
        AccessManager accessManager;
        OracleRegistry oracleRegistry;
        SwapModule swapModule;
        HubCoreRegistry hubCoreRegistry;
        TokenRegistry tokenRegistry;
        ChainRegistry chainRegistry;
        UpgradeableBeacon caliberBeacon;
        UpgradeableBeacon machineBeacon;
        UpgradeableBeacon preDepositVaultBeacon;
        MachineFactory machineFactory;
    }

    struct SpokeCore {
        AccessManager accessManager;
        OracleRegistry oracleRegistry;
        SwapModule swapModule;
        SpokeCoreRegistry spokeCoreRegistry;
        TokenRegistry tokenRegistry;
        UpgradeableBeacon caliberBeacon;
        CaliberFactory caliberFactory;
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
        returns (
            AccessManager accessManager,
            OracleRegistry oracleRegistry,
            TokenRegistry tokenRegistry,
            SwapModule swapModule
        )
    {
        accessManager = new AccessManager(initialAMAdmin);

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

        address swapModuleImplemAddr = address(new SwapModule());
        swapModule = SwapModule(
            address(
                new TransparentUpgradeableProxy(
                    swapModuleImplemAddr, dao, abi.encodeCall(SwapModule.initialize, (address(accessManager)))
                )
            )
        );
    }

    function deployHubCore(address initialAMAdmin, address dao, address wormhole)
        internal
        returns (HubCore memory deployment)
    {
        (deployment.accessManager, deployment.oracleRegistry, deployment.tokenRegistry, deployment.swapModule) =
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
                            address(deployment.swapModule),
                            address(deployment.accessManager)
                        )
                    )
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

        address machineFactoryImplemAddr = address(new MachineFactory(address(deployment.hubCoreRegistry)));
        deployment.machineFactory = MachineFactory(
            address(
                new TransparentUpgradeableProxy(
                    machineFactoryImplemAddr,
                    dao,
                    abi.encodeCall(MachineFactory.initialize, (address(deployment.accessManager)))
                )
            )
        );
    }

    function deploySpokeCore(address initialAMAdmin, address dao, uint256 hubChainId)
        internal
        returns (SpokeCore memory deployment)
    {
        (deployment.accessManager, deployment.oracleRegistry, deployment.tokenRegistry, deployment.swapModule) =
            deploySharedCore(initialAMAdmin, dao);

        deployment.spokeCoreRegistry = _deploySpokeCoreRegistry(
            dao,
            address(deployment.oracleRegistry),
            address(deployment.tokenRegistry),
            address(deployment.swapModule),
            address(deployment.accessManager)
        );

        address weirollVMImplemAddr = deployWeirollVMViaIR();
        address caliberImplemAddr = address(new Caliber(address(deployment.spokeCoreRegistry), weirollVMImplemAddr));
        deployment.caliberBeacon = new UpgradeableBeacon(caliberImplemAddr, dao);

        deployment.caliberFactory =
            _deployCaliberFactory(dao, address(deployment.spokeCoreRegistry), address(deployment.accessManager));

        deployment.caliberMailboxBeacon =
            _deployCaliberMailboxBeacon(dao, address(deployment.spokeCoreRegistry), hubChainId);
    }

    ///
    /// REGISTRIES SETUP
    ///

    function setupHubCoreRegistry(HubCore memory deployment) public {
        deployment.hubCoreRegistry.setTokenRegistry(address(deployment.tokenRegistry));
        deployment.hubCoreRegistry.setChainRegistry(address(deployment.chainRegistry));
        deployment.hubCoreRegistry.setCoreFactory(address(deployment.machineFactory));
        deployment.hubCoreRegistry.setCaliberBeacon(address(deployment.caliberBeacon));
        deployment.hubCoreRegistry.setMachineBeacon(address(deployment.machineBeacon));
        deployment.hubCoreRegistry.setPreDepositVaultBeacon(address(deployment.preDepositVaultBeacon));
    }

    function setupSpokeCoreRegistry(SpokeCore memory deployment) public {
        deployment.spokeCoreRegistry.setTokenRegistry(address(deployment.tokenRegistry));
        deployment.spokeCoreRegistry.setCoreFactory(address(deployment.caliberFactory));
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
                baBeacon = address(_deployAccrossV3BridgeAdapterBeacon(dao, bridgesData[i].executionTarget));
            } else {
                revert("Bridge not supported");
            }
            makinaRegistry.setBridgeAdapterBeacon(bridgeId, baBeacon);
        }
    }

    ///
    /// ACCESS MANAGER SETUP
    ///

    function setupAccessManager(AccessManager accessManager, address dao) public {
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
        address _swapModule,
        address _accessManager
    ) internal returns (SpokeCoreRegistry spokeCoreRegistry) {
        address spokeCoreRegistryImplemAddr = address(new SpokeCoreRegistry());
        return SpokeCoreRegistry(
            address(
                new TransparentUpgradeableProxy(
                    spokeCoreRegistryImplemAddr,
                    _dao,
                    abi.encodeCall(
                        SpokeCoreRegistry.initialize, (_oracleRegistry, _tokenRegistry, _swapModule, _accessManager)
                    )
                )
            )
        );
    }

    function _deployCaliberFactory(address _dao, address _spokeCoreRegistry, address _accessManager)
        internal
        returns (CaliberFactory caliberFactory)
    {
        address caliberFactoryImplemAddr = address(new CaliberFactory(_spokeCoreRegistry));
        return CaliberFactory(
            address(
                new TransparentUpgradeableProxy(
                    caliberFactoryImplemAddr, _dao, abi.encodeCall(CaliberFactory.initialize, (_accessManager))
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

    function _deployAccrossV3BridgeAdapterBeacon(address _dao, address _acrossV3SpokePool)
        internal
        returns (UpgradeableBeacon acrossV3BridgeAdapterBeacon)
    {
        address acrossV3BridgeAdapterImplemAddr = address(new AcrossV3BridgeAdapter(_acrossV3SpokePool));
        return UpgradeableBeacon(address(new UpgradeableBeacon(acrossV3BridgeAdapterImplemAddr, _dao)));
    }
}
