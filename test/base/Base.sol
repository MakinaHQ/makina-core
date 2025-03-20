// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {StdCheats} from "forge-std/StdCheats.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ChainsInfo} from "../utils/ChainsInfo.sol";
import {Caliber} from "src/caliber/Caliber.sol";
import {CaliberFactory} from "src/factories/CaliberFactory.sol";
import {ChainRegistry} from "src/registries/ChainRegistry.sol";
import {HubDualMailbox} from "src/mailbox/HubDualMailbox.sol";
import {HubRegistry} from "src/registries/HubRegistry.sol";
import {ISwapModule} from "src/interfaces/ISwapModule.sol";
import {Machine} from "src/machine/Machine.sol";
import {MachineFactory} from "src/factories/MachineFactory.sol";
import {OracleRegistry} from "src/registries/OracleRegistry.sol";
import {SpokeCaliberMailbox} from "src/mailbox/SpokeCaliberMailbox.sol";
import {SpokeMachineMailbox} from "src/mailbox/SpokeMachineMailbox.sol";
import {SpokeRegistry} from "src/registries/SpokeRegistry.sol";
import {SwapModule} from "src/swap/SwapModule.sol";

abstract contract Base is StdCheats {
    struct HubCore {
        AccessManager accessManager;
        OracleRegistry oracleRegistry;
        SwapModule swapModule;
        HubRegistry hubRegistry;
        ChainRegistry chainRegistry;
        UpgradeableBeacon hubCaliberBeacon;
        UpgradeableBeacon machineBeacon;
        MachineFactory machineFactory;
        UpgradeableBeacon hubDualMailboxBeacon;
        UpgradeableBeacon spokeMachineMailboxBeacon;
    }

    struct SpokeCore {
        AccessManager accessManager;
        OracleRegistry oracleRegistry;
        SwapModule swapModule;
        UpgradeableBeacon spokeCaliberBeacon;
        CaliberFactory caliberFactory;
        SpokeRegistry spokeRegistry;
        UpgradeableBeacon spokeCaliberMailboxBeacon;
    }

    struct PriceFeedData {
        address feed1;
        address feed2;
        uint256 stalenessThreshold1;
        uint256 stalenessThreshold2;
        address token;
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
        returns (AccessManager accessManager, OracleRegistry oracleRegistry, SwapModule swapModule)
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
        (deployment.accessManager, deployment.oracleRegistry, deployment.swapModule) =
            deploySharedCore(initialAMAdmin, dao);

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
                            address(deployment.swapModule),
                            address(deployment.accessManager)
                        )
                    )
                )
            )
        );

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

        address weirollVMImplemAddr = deployWeirollVMViaIR();
        address caliberImplemAddr = address(new Caliber(address(deployment.hubRegistry), weirollVMImplemAddr));
        deployment.hubCaliberBeacon = new UpgradeableBeacon(caliberImplemAddr, dao);

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

        address HubDualMailboxImplemAddr = address(new HubDualMailbox());
        deployment.hubDualMailboxBeacon = new UpgradeableBeacon(HubDualMailboxImplemAddr, dao);

        address spokeMachineMailboxImplemAddr = address(new SpokeMachineMailbox());
        deployment.spokeMachineMailboxBeacon = new UpgradeableBeacon(spokeMachineMailboxImplemAddr, dao);
    }

    function deploySpokeCore(address initialAMAdmin, address dao, uint256 hubChainId)
        internal
        returns (SpokeCore memory deployment)
    {
        (deployment.accessManager, deployment.oracleRegistry, deployment.swapModule) =
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
                            address(deployment.swapModule),
                            address(deployment.accessManager)
                        )
                    )
                )
            )
        );

        address weirollVMImplemAddr = deployWeirollVMViaIR();
        address caliberImplemAddr = address(new Caliber(address(deployment.spokeRegistry), weirollVMImplemAddr));
        deployment.spokeCaliberBeacon = new UpgradeableBeacon(caliberImplemAddr, dao);

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

        address spokeCaliberMailboxImplemAddr = address(new SpokeCaliberMailbox(hubChainId));
        deployment.spokeCaliberMailboxBeacon = new UpgradeableBeacon(spokeCaliberMailboxImplemAddr, dao);
    }

    ///
    /// REGISTRIES SETUP
    ///

    function setupHubRegistry(HubCore memory deployment) public {
        deployment.hubRegistry.setChainRegistry(address(deployment.chainRegistry));
        deployment.hubRegistry.setMachineFactory(address(deployment.machineFactory));
        deployment.hubRegistry.setMachineBeacon(address(deployment.machineBeacon));
        deployment.hubRegistry.setCaliberBeacon(address(deployment.hubCaliberBeacon));
        deployment.hubRegistry.setHubDualMailboxBeacon(address(deployment.hubDualMailboxBeacon));
        deployment.hubRegistry.setSpokeMachineMailboxBeacon(address(deployment.spokeMachineMailboxBeacon));
    }

    function setupSpokeRegistry(SpokeCore memory deployment) public {
        deployment.spokeRegistry.setCaliberFactory(address(deployment.caliberFactory));
        deployment.spokeRegistry.setCaliberBeacon(address(deployment.spokeCaliberBeacon));
        deployment.spokeRegistry.setSpokeCaliberMailboxBeacon(address(deployment.spokeCaliberMailboxBeacon));
    }

    function setupOracleRegistry(OracleRegistry oracleRegistry, PriceFeedData[] memory priceFeedData) public {
        for (uint256 i; i < priceFeedData.length; i++) {
            oracleRegistry.setTokenFeedData(
                priceFeedData[i].token,
                priceFeedData[i].feed1,
                priceFeedData[i].stalenessThreshold1,
                priceFeedData[i].feed2,
                priceFeedData[i].stalenessThreshold2
            );
        }
    }

    function setupChainRegistry(ChainRegistry chainRegistry, uint256[] memory evmChainIds) public {
        for (uint256 i; i < evmChainIds.length; i++) {
            uint256 evmChainId = evmChainIds[i];
            chainRegistry.setChainIds(evmChainId, ChainsInfo.getChainInfo(evmChainId).wormholeChainId);
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
