// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

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
import {HubCaliberInbox} from "../src/caliber/HubCaliberInbox.sol";
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

    UpgradeableBeacon public caliberBeacon;
    UpgradeableBeacon public caliberInboxBeacon;

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
                        HubRegistry.initialize,
                        (
                            IHubRegistry.initParams({
                                oracleRegistry: address(oracleRegistry),
                                swapper: address(swapper),
                                initialAuthority: address(accessManager)
                            })
                        )
                    )
                )
            )
        );

        address caliberImplem = address(new Caliber(address(hubRegistry)));
        caliberBeacon = new UpgradeableBeacon(caliberImplem, dao);
        caliberInboxBeacon = new UpgradeableBeacon(address(new HubCaliberInbox()), dao);

        caliberFactory = CaliberFactory(
            address(
                new TransparentUpgradeableProxy(
                    address(new CaliberFactory(address(hubRegistry))),
                    dao,
                    abi.encodeCall(CaliberFactory.initialize, (address(accessManager)))
                )
            )
        );
    }
}
