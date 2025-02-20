// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {OracleRegistry} from "../src/OracleRegistry.sol";
import {Swapper} from "../src/swap/Swapper.sol";
import {HubRegistry} from "../src/registries/HubRegistry.sol";
import {SpokeRegistry} from "../src/registries/SpokeRegistry.sol";
import {Machine} from "../src/machine/Machine.sol";
import {Caliber} from "../src/caliber/Caliber.sol";
import {CaliberFactory} from "../src/factories/CaliberFactory.sol";
import {MachineFactory} from "../src/factories/MachineFactory.sol";
import {HubDualMailbox} from "../src/mailbox/HubDualMailbox.sol";
import {SpokeCaliberMailbox} from "../src/mailbox/SpokeCaliberMailbox.sol";
import {SpokeMachineMailbox} from "../src/mailbox/SpokeMachineMailbox.sol";

abstract contract Base is Script, Test {
    address public deployer;

    uint256 public hubChainId;

    address public dao;
    address public mechanic;
    address public securityCouncil;

    // Shared
    AccessManager public accessManager;
    OracleRegistry public oracleRegistry;
    Swapper public swapper;

    // Hub
    HubRegistry public hubRegistry;
    UpgradeableBeacon public hubCaliberBeacon;
    UpgradeableBeacon public machineBeacon;
    MachineFactory public machineFactory;
    UpgradeableBeacon public hubDualMailboxBeacon;
    UpgradeableBeacon public spokeMachineMailboxBeacon;

    // Spoke
    UpgradeableBeacon public spokeCaliberBeacon;
    CaliberFactory public spokeCaliberFactory;
    SpokeRegistry public spokeRegistry;
    UpgradeableBeacon public spokeCaliberMailboxBeacon;

    function _coreSharedSetup() public {
        accessManager = new AccessManager(deployer);

        address oracleRegistryImplemAddr = address(new OracleRegistry());
        oracleRegistry = OracleRegistry(
            address(
                new TransparentUpgradeableProxy(
                    oracleRegistryImplemAddr, dao, abi.encodeCall(OracleRegistry.initialize, (address(accessManager)))
                )
            )
        );

        address swapperImplemAddr = address(new Swapper());
        swapper = Swapper(
            address(
                new TransparentUpgradeableProxy(
                    swapperImplemAddr, dao, abi.encodeCall(Swapper.initialize, (address(accessManager)))
                )
            )
        );
    }

    function _coreHubSetup() public {
        address hubRegistryImplemAddr = address(new HubRegistry());
        hubRegistry = HubRegistry(
            address(
                new TransparentUpgradeableProxy(
                    hubRegistryImplemAddr,
                    dao,
                    abi.encodeCall(
                        HubRegistry.initialize, (address(oracleRegistry), address(swapper), address(accessManager))
                    )
                )
            )
        );

        address caliberImplemAddr = address(new Caliber(address(hubRegistry)));
        hubCaliberBeacon = new UpgradeableBeacon(caliberImplemAddr, dao);

        address machineImplemAddr = address(new Machine(address(hubRegistry)));
        machineBeacon = new UpgradeableBeacon(machineImplemAddr, dao);

        address machineFactoryImplemAddr = address(new MachineFactory(address(hubRegistry)));
        machineFactory = MachineFactory(
            address(
                new TransparentUpgradeableProxy(
                    machineFactoryImplemAddr, dao, abi.encodeCall(MachineFactory.initialize, (address(accessManager)))
                )
            )
        );

        address HubDualMailboxImplemAddr = address(new HubDualMailbox());
        hubDualMailboxBeacon = new UpgradeableBeacon(HubDualMailboxImplemAddr, dao);

        address spokeMachineMailboxImplemAddr = address(new SpokeMachineMailbox());
        spokeMachineMailboxBeacon = new UpgradeableBeacon(spokeMachineMailboxImplemAddr, dao);
    }

    function _coreSpokeSetup() public {
        address spokeRegistryImplemAddr = address(new SpokeRegistry());
        spokeRegistry = SpokeRegistry(
            address(
                new TransparentUpgradeableProxy(
                    spokeRegistryImplemAddr,
                    dao,
                    abi.encodeCall(
                        SpokeRegistry.initialize, (address(oracleRegistry), address(swapper), address(accessManager))
                    )
                )
            )
        );

        address caliberImplemAddr = address(new Caliber(address(spokeRegistry)));
        spokeCaliberBeacon = new UpgradeableBeacon(caliberImplemAddr, dao);

        address caliberFactoryImplemAddr = address(new CaliberFactory(address(spokeRegistry)));
        spokeCaliberFactory = CaliberFactory(
            address(
                new TransparentUpgradeableProxy(
                    caliberFactoryImplemAddr, dao, abi.encodeCall(CaliberFactory.initialize, (address(accessManager)))
                )
            )
        );

        address spokeCaliberMailboxImplemAddr = address(new SpokeCaliberMailbox(hubChainId));
        spokeCaliberMailboxBeacon = new UpgradeableBeacon(spokeCaliberMailboxImplemAddr, dao);
    }

    function _hubRegistrySetup() public {
        hubRegistry.setCaliberBeacon(address(hubCaliberBeacon));
        hubRegistry.setMachineBeacon(address(machineBeacon));
        hubRegistry.setMachineFactory(address(machineFactory));
        hubRegistry.setHubDualMailboxBeacon(address(hubDualMailboxBeacon));
    }

    function _spokeRegistrySetup() public {
        spokeRegistry.setCaliberBeacon(address(spokeCaliberBeacon));
        spokeRegistry.setCaliberFactory(address(spokeCaliberFactory));
        spokeRegistry.setSpokeCaliberMailboxBeacon(address(spokeCaliberMailboxBeacon));
    }
}
