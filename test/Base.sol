// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IHubRegistry} from "../src/interfaces/IHubRegistry.sol";
import {HubRegistry} from "../src/registries/HubRegistry.sol";
import {OracleRegistry} from "../src/OracleRegistry.sol";
import {CaliberFactory} from "../src/factories/CaliberFactory.sol";
import {Caliber} from "../src/caliber/Caliber.sol";
import {HubDualMailbox} from "../src/mailbox/HubDualMailbox.sol";
import {MachineFactory} from "../src/factories/MachineFactory.sol";
import {Machine} from "../src/machine/Machine.sol";
import {Swapper} from "../src/swap/Swapper.sol";

abstract contract Base is Script, Test {
    address public deployer;

    address public dao;
    address public mechanic;
    address public securityCouncil;

    AccessManager public accessManager;

    HubRegistry public hubRegistry;

    OracleRegistry public oracleRegistry;
    Swapper public swapper;

    CaliberFactory public caliberFactory;
    MachineFactory public machineFactory;

    UpgradeableBeacon public caliberBeacon;
    UpgradeableBeacon public machineBeacon;

    UpgradeableBeacon public hubDualMailboxBeacon;

    function _coreSetup() public {
        accessManager = new AccessManager(deployer);

        oracleRegistry = OracleRegistry(
            address(
                new TransparentUpgradeableProxy(
                    address(new OracleRegistry()),
                    dao,
                    abi.encodeCall(OracleRegistry.initialize, (address(accessManager)))
                )
            )
        );

        swapper = Swapper(
            address(
                new TransparentUpgradeableProxy(
                    address(new Swapper()), dao, abi.encodeCall(Swapper.initialize, (address(accessManager)))
                )
            )
        );

        hubRegistry = HubRegistry(
            address(
                new TransparentUpgradeableProxy(
                    address(new HubRegistry()),
                    dao,
                    abi.encodeCall(
                        HubRegistry.initialize, (address(oracleRegistry), address(swapper), address(accessManager))
                    )
                )
            )
        );

        address caliberImplem = address(new Caliber(address(hubRegistry)));
        caliberBeacon = new UpgradeableBeacon(caliberImplem, dao);

        address machineImplem = address(new Machine(address(hubRegistry)));
        machineBeacon = new UpgradeableBeacon(machineImplem, dao);

        caliberFactory = CaliberFactory(
            address(
                new TransparentUpgradeableProxy(
                    address(new CaliberFactory(address(hubRegistry))),
                    dao,
                    abi.encodeCall(CaliberFactory.initialize, (address(accessManager)))
                )
            )
        );

        machineFactory = MachineFactory(
            address(
                new TransparentUpgradeableProxy(
                    address(new MachineFactory(address(hubRegistry))),
                    dao,
                    abi.encodeCall(MachineFactory.initialize, (address(accessManager)))
                )
            )
        );

        hubDualMailboxBeacon = new UpgradeableBeacon(address(new HubDualMailbox()), dao);
    }
}
