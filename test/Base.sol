// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {OracleRegistry} from "../src/OracleRegistry.sol";
import {CaliberFactory} from "../src/factories/CaliberFactory.sol";
import {Caliber} from "../src/caliber/Caliber.sol";
import {HubCaliberInbox} from "../src/caliber/HubCaliberInbox.sol";
import {Swapper} from "../src/swap/Swapper.sol";

abstract contract Base is Script, Test {
    address public dao;
    address public mechanic;
    address public securityCouncil;

    AccessManager public accessManager;

    OracleRegistry public oracleRegistry;
    Swapper public swapper;
    CaliberFactory public caliberFactory;

    function _coreSetup() public {
        accessManager = new AccessManager(dao);

        oracleRegistry = OracleRegistry(
            address(
                new TransparentUpgradeableProxy(
                    address(new OracleRegistry()),
                    dao,
                    abi.encodeWithSelector(OracleRegistry(address(0)).initialize.selector, accessManager)
                )
            )
        );

        swapper = Swapper(
            address(
                new TransparentUpgradeableProxy(
                    address(new Swapper()),
                    dao,
                    abi.encodeWithSelector(Swapper(address(0)).initialize.selector, accessManager)
                )
            )
        );

        address caliberInboxBeaconAddr = address(new UpgradeableBeacon(address(new HubCaliberInbox()), dao));
        address caliberBeaconAddr =
            address(new UpgradeableBeacon(address(new Caliber(address(oracleRegistry), address(swapper))), dao));

        caliberFactory = CaliberFactory(
            address(
                new TransparentUpgradeableProxy(
                    address(new CaliberFactory(caliberBeaconAddr, caliberInboxBeaconAddr)),
                    dao,
                    abi.encodeWithSelector(CaliberFactory(address(0)).initialize.selector, accessManager)
                )
            )
        );
    }
}
