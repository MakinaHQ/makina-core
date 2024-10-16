// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {OracleRegistry} from "../src/OracleRegistry.sol";

abstract contract Base is Script, Test {
    address dao;
    address mechanic;

    AccessManager accessManager;

    OracleRegistry oracleRegistry;
    uint256 defaultFeedStalenessThreshold;

    function _coreSetup() public {
        accessManager = new AccessManager(dao);

        oracleRegistry = OracleRegistry(
            address(
                new TransparentUpgradeableProxy(
                    address(new OracleRegistry()),
                    address(this),
                    abi.encodeWithSelector(
                        OracleRegistry(address(0)).initialize.selector, defaultFeedStalenessThreshold, accessManager
                    )
                )
            )
        );
    }
}
