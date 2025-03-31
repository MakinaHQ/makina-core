// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {StdCheats} from "forge-std/StdCheats.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ChainsInfo} from "../utils/ChainsInfo.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {CaliberFactory} from "src/factories/CaliberFactory.sol";
import {CaliberMailbox} from "src/caliber/CaliberMailbox.sol";
import {ChainRegistry} from "src/registries/ChainRegistry.sol";
import {HubRegistry} from "src/registries/HubRegistry.sol";
import {ISwapModule} from "src/interfaces/ISwapModule.sol";
import {Machine} from "src/machine/Machine.sol";
import {MachineFactory} from "src/factories/MachineFactory.sol";
import {OracleRegistry} from "src/registries/OracleRegistry.sol";
import {SpokeRegistry} from "src/registries/SpokeRegistry.sol";
import {SwapModule} from "src/swap/SwapModule.sol";
import {TokenRegistry} from "src/registries/TokenRegistry.sol";

abstract contract Base is StdCheats {
    struct HubCore {
        AccessManager accessManager;
        OracleRegistry oracleRegistry;
        SwapModule swapModule;
        HubRegistry hubRegistry;
        ChainRegistry chainRegistry;
        TokenRegistry tokenRegistry;
        UpgradeableBeacon caliberBeacon;
        UpgradeableBeacon machineBeacon;
        MachineFactory machineFactory;
    }

    struct SpokeCore {
        AccessManager accessManager;
        OracleRegistry oracleRegistry;
        TokenRegistry tokenRegistry;
        SwapModule swapModule;
        UpgradeableBeacon caliberBeacon;
        CaliberFactory caliberFactory;
        SpokeRegistry spokeRegistry;
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
        ISwapModule.Swapper swapperId;
    }

    ///
    /// CORE DEPLOYMENTS
    ///

    function deployWeirollVMViaIR() public returns (address weirollVM) {
        weirollVM = deployCode("out-ir-based/WeirollVM.sol/WeirollVM.json");
    }

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

        address hubRegistryImplemAddr = address(new HubRegistry());
        deployment.hubRegistry = HubRegistry(
            address(
                new TransparentUpgradeableProxy(
                    hubRegistryImplemAddr,
                    dao,
                    abi.encodeCall(
                        HubRegistry.initialize,
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

        address weirollVMImplemAddr = deployWeirollVMViaIR();
        address caliberImplemAddr = address(new Caliber(address(deployment.hubRegistry), weirollVMImplemAddr));
        deployment.caliberBeacon = new UpgradeableBeacon(caliberImplemAddr, dao);

        address machineImplemAddr = address(new Machine(address(deployment.hubRegistry), wormhole));
        deployment.machineBeacon = new UpgradeableBeacon(machineImplemAddr, dao);

        address machineFactoryImplemAddr = address(new MachineFactory(address(deployment.hubRegistry)));
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

        address spokeRegistryImplemAddr = address(new SpokeRegistry());
        deployment.spokeRegistry = SpokeRegistry(
            address(
                new TransparentUpgradeableProxy(
                    spokeRegistryImplemAddr,
                    dao,
                    abi.encodeCall(
                        SpokeRegistry.initialize,
                        (
                            address(deployment.oracleRegistry),
                            address(deployment.tokenRegistry),
                            address(deployment.swapModule),
                            address(deployment.accessManager)
                        )
                    )
                )
            )
        );

        address weirollVMImplemAddr = deployWeirollVMViaIR();
        address caliberImplemAddr = address(new Caliber(address(deployment.spokeRegistry), weirollVMImplemAddr));
        deployment.caliberBeacon = new UpgradeableBeacon(caliberImplemAddr, dao);

        address caliberFactoryImplemAddr = address(new CaliberFactory(address(deployment.spokeRegistry)));
        deployment.caliberFactory = CaliberFactory(
            address(
                new TransparentUpgradeableProxy(
                    caliberFactoryImplemAddr,
                    dao,
                    abi.encodeCall(CaliberFactory.initialize, (address(deployment.accessManager)))
                )
            )
        );

        address caliberMailboxImplemAddr = address(new CaliberMailbox(address(deployment.spokeRegistry), hubChainId));
        deployment.caliberMailboxBeacon = new UpgradeableBeacon(caliberMailboxImplemAddr, dao);
    }

    ///
    /// REGISTRIES SETUP
    ///

    function setupHubRegistry(HubCore memory deployment) public {
        deployment.hubRegistry.setMachineFactory(address(deployment.machineFactory));
        deployment.hubRegistry.setMachineBeacon(address(deployment.machineBeacon));
        deployment.hubRegistry.setCaliberBeacon(address(deployment.caliberBeacon));
    }

    function setupSpokeRegistry(SpokeCore memory deployment) public {
        deployment.spokeRegistry.setCaliberFactory(address(deployment.caliberFactory));
        deployment.spokeRegistry.setCaliberBeacon(address(deployment.caliberBeacon));
        deployment.spokeRegistry.setCaliberMailboxBeacon(address(deployment.caliberMailboxBeacon));
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
    /// ACCESS MANAGER SETUP
    ///

    function setupAccessManager(AccessManager accessManager, address dao) public {
        accessManager.grantRole(accessManager.ADMIN_ROLE(), dao, 0);
        accessManager.revokeRole(accessManager.ADMIN_ROLE(), address(this));
    }
}
