// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

abstract contract Base is Script, Test {
    address dao;

    AccessManager public accessManager;

    function _coreSetup() public {
        accessManager = new AccessManager(dao);
    }
}
